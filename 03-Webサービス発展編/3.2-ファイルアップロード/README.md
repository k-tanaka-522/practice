# 3.2-ファイルアップロード

S3を活用した画像アップロード機能を実装し、投稿に画像を添付できる機能を追加します。

## 学習目標

- S3バケットの設定とセキュリティ
- マルチパートファイルアップロード
- 画像リサイズとフォーマット変換
- CDN配信設定
- プログレスバー付きアップロード

## 機能要件

### アップロード機能
- 画像ファイルのドラッグ&ドロップ
- 複数ファイル選択対応
- アップロード進捗表示
- プレビュー機能
- ファイルサイズ・形式制限

### 画像処理機能
- 自動リサイズ（複数サイズ生成）
- フォーマット最適化（WebP変換）
- サムネイル生成
- EXIF情報除去

### 配信機能
- CloudFront経由配信
- キャッシュ最適化
- レスポンシブ画像配信

## アーキテクチャ

```
Frontend → API Gateway → Lambda → S3
                    ↓
              Lambda (画像処理) → S3 (変換済み)
                    ↓
              CloudFront → ユーザー
```

## 実装手順

### Step 1: インフラストラクチャ構築

S3バケット、Lambda関数、CloudFrontをCloudFormationで作成します。

```bash
# CloudFormationスタック作成
aws cloudformation create-stack \
  --stack-name sns-file-upload \
  --template-body file://cloudformation/file-upload.yaml \
  --capabilities CAPABILITY_IAM
```

### Step 2: バックエンド実装

#### 2-1. プロジェクト構造
```
backend/
├── src/
│   ├── handlers/
│   │   ├── upload.js
│   │   └── imageProcessor.js
│   ├── services/
│   │   ├── s3Service.js
│   │   └── imageService.js
│   ├── utils/
│   │   ├── fileValidator.js
│   │   └── imageUtils.js
│   └── config/
│       └── s3.js
├── layers/
│   └── sharp-layer/
│       └── nodejs/
│           └── node_modules/
└── package.json
```

#### 2-2. S3設定

```javascript
// src/config/s3.js
const AWS = require('aws-sdk');

const s3 = new AWS.S3({
  region: process.env.AWS_REGION || 'ap-northeast-1',
  signatureVersion: 'v4'
});

const UPLOAD_BUCKET = process.env.UPLOAD_BUCKET;
const PROCESSED_BUCKET = process.env.PROCESSED_BUCKET;

// 設定
const UPLOAD_CONFIG = {
  maxFileSize: 10 * 1024 * 1024, // 10MB
  allowedMimeTypes: [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp'
  ],
  allowedExtensions: ['.jpg', '.jpeg', '.png', '.gif', '.webp'],
  resizeSizes: {
    thumbnail: { width: 150, height: 150 },
    small: { width: 400, height: 400 },
    medium: { width: 800, height: 600 },
    large: { width: 1200, height: 900 }
  }
};

module.exports = {
  s3,
  UPLOAD_BUCKET,
  PROCESSED_BUCKET,
  UPLOAD_CONFIG
};
```

#### 2-3. ファイルバリデーションユーティリティ

```javascript
// src/utils/fileValidator.js
const { UPLOAD_CONFIG } = require('../config/s3');

class FileValidator {
  static validateFile(file) {
    const errors = [];

    // ファイルサイズチェック
    if (file.size > UPLOAD_CONFIG.maxFileSize) {
      errors.push(`File size exceeds limit of ${UPLOAD_CONFIG.maxFileSize / 1024 / 1024}MB`);
    }

    // MIMEタイプチェック
    if (!UPLOAD_CONFIG.allowedMimeTypes.includes(file.type)) {
      errors.push(`File type ${file.type} is not allowed`);
    }

    // ファイル名拡張子チェック
    const fileExtension = file.name.toLowerCase().match(/\.[^.]+$/)?.[0];
    if (!fileExtension || !UPLOAD_CONFIG.allowedExtensions.includes(fileExtension)) {
      errors.push(`File extension ${fileExtension} is not allowed`);
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  static generateFileName(originalName, userId) {
    const timestamp = Date.now();
    const randomString = Math.random().toString(36).substring(7);
    const extension = originalName.toLowerCase().match(/\.[^.]+$/)?.[0] || '.jpg';
    
    return `uploads/${userId}/${timestamp}-${randomString}${extension}`;
  }

  static generateProcessedFileName(originalKey, size, format = 'webp') {
    const baseName = originalKey.replace(/\.[^.]+$/, '');
    return `processed/${baseName}-${size}.${format}`;
  }
}

module.exports = FileValidator;
```

#### 2-4. S3サービス

```javascript
// src/services/s3Service.js
const { s3, UPLOAD_BUCKET, PROCESSED_BUCKET } = require('../config/s3');
const FileValidator = require('../utils/fileValidator');

class S3Service {
  // プリサインドURL生成（アップロード用）
  async generateUploadUrl(fileName, contentType, userId) {
    const validation = FileValidator.validateFile({
      name: fileName,
      type: contentType,
      size: 0 // サイズは後でチェック
    });

    if (!validation.isValid) {
      throw new Error(`Validation failed: ${validation.errors.join(', ')}`);
    }

    const key = FileValidator.generateFileName(fileName, userId);
    
    const params = {
      Bucket: UPLOAD_BUCKET,
      Key: key,
      ContentType: contentType,
      Expires: 300, // 5分有効
      Conditions: [
        ['content-length-range', 0, 10485760], // 10MB制限
        ['starts-with', '$Content-Type', 'image/']
      ]
    };

    const uploadUrl = await s3.getSignedUrlPromise('putObject', params);
    
    return {
      uploadUrl,
      key,
      fileName
    };
  }

  // ダイレクトアップロード用プリサインドPOST
  async generateUploadPost(fileName, contentType, userId) {
    const key = FileValidator.generateFileName(fileName, userId);
    
    const params = {
      Bucket: UPLOAD_BUCKET,
      Key: key,
      Expires: 300,
      Conditions: [
        { 'Content-Type': contentType },
        ['content-length-range', 0, 10485760],
        ['starts-with', '$key', `uploads/${userId}/`]
      ],
      Fields: {
        'Content-Type': contentType
      }
    };

    const postData = await s3.createPresignedPost(params);
    
    return {
      ...postData,
      key,
      fileName
    };
  }

  // ファイル存在確認
  async fileExists(bucket, key) {
    try {
      await s3.headObject({ Bucket: bucket, Key: key }).promise();
      return true;
    } catch (error) {
      if (error.statusCode === 404) {
        return false;
      }
      throw error;
    }
  }

  // ファイル削除
  async deleteFile(bucket, key) {
    const params = {
      Bucket: bucket,
      Key: key
    };

    await s3.deleteObject(params).promise();
  }

  // 複数ファイル削除
  async deleteFiles(bucket, keys) {
    if (!keys || keys.length === 0) return;

    const params = {
      Bucket: bucket,
      Delete: {
        Objects: keys.map(key => ({ Key: key }))
      }
    };

    await s3.deleteObjects(params).promise();
  }

  // ファイル情報取得
  async getFileInfo(bucket, key) {
    const params = {
      Bucket: bucket,
      Key: key
    };

    const data = await s3.headObject(params).promise();
    
    return {
      size: data.ContentLength,
      lastModified: data.LastModified,
      contentType: data.ContentType,
      etag: data.ETag
    };
  }

  // CloudFront URL生成
  generateCloudFrontUrl(key) {
    const cloudFrontDomain = process.env.CLOUDFRONT_DOMAIN;
    if (!cloudFrontDomain) {
      return `https://${PROCESSED_BUCKET}.s3.amazonaws.com/${key}`;
    }
    return `https://${cloudFrontDomain}/${key}`;
  }
}

module.exports = new S3Service();
```

#### 2-5. 画像処理サービス

```javascript
// src/services/imageService.js
const AWS = require('aws-sdk');
const sharp = require('sharp');
const { s3, UPLOAD_BUCKET, PROCESSED_BUCKET, UPLOAD_CONFIG } = require('../config/s3');
const FileValidator = require('../utils/fileValidator');

class ImageService {
  async processImage(bucket, key) {
    try {
      console.log(`Processing image: ${key}`);

      // 元画像取得
      const originalImage = await s3.getObject({
        Bucket: bucket,
        Key: key
      }).promise();

      const imageBuffer = originalImage.Body;
      const sharpImage = sharp(imageBuffer);
      const metadata = await sharpImage.metadata();

      console.log(`Image metadata:`, metadata);

      // 各サイズの画像を生成
      const processedImages = await Promise.all(
        Object.entries(UPLOAD_CONFIG.resizeSizes).map(async ([sizeName, dimensions]) => {
          return this.resizeImage(imageBuffer, sizeName, dimensions, key);
        })
      );

      // 処理結果をS3に保存
      const uploadPromises = processedImages.map(async (processed) => {
        const uploadParams = {
          Bucket: PROCESSED_BUCKET,
          Key: processed.key,
          Body: processed.buffer,
          ContentType: 'image/webp',
          CacheControl: 'max-age=31536000', // 1年キャッシュ
          Metadata: {
            originalKey: key,
            size: processed.sizeName,
            width: processed.width.toString(),
            height: processed.height.toString()
          }
        };

        await s3.upload(uploadParams).promise();
        return processed;
      });

      const results = await Promise.all(uploadPromises);

      console.log(`Successfully processed ${results.length} image sizes`);

      return {
        original: {
          key,
          width: metadata.width,
          height: metadata.height,
          size: originalImage.ContentLength
        },
        processed: results.map(result => ({
          sizeName: result.sizeName,
          key: result.key,
          width: result.width,
          height: result.height,
          url: this.generateCloudFrontUrl(result.key)
        }))
      };

    } catch (error) {
      console.error(`Error processing image ${key}:`, error);
      throw error;
    }
  }

  async resizeImage(imageBuffer, sizeName, dimensions, originalKey) {
    const { width, height } = dimensions;
    
    const resized = await sharp(imageBuffer)
      .resize(width, height, {
        fit: 'inside',
        withoutEnlargement: true
      })
      .webp({
        quality: 85,
        effort: 4
      })
      .toBuffer();

    const processedKey = FileValidator.generateProcessedFileName(originalKey, sizeName, 'webp');
    
    // リサイズ後の実際のサイズを取得
    const metadata = await sharp(resized).metadata();

    return {
      sizeName,
      key: processedKey,
      buffer: resized,
      width: metadata.width,
      height: metadata.height
    };
  }

  generateCloudFrontUrl(key) {
    const cloudFrontDomain = process.env.CLOUDFRONT_DOMAIN;
    if (!cloudFrontDomain) {
      return `https://${PROCESSED_BUCKET}.s3.amazonaws.com/${key}`;
    }
    return `https://${cloudFrontDomain}/${key}`;
  }

  // 画像メタデータ取得
  async getImageMetadata(bucket, key) {
    try {
      const imageObject = await s3.getObject({
        Bucket: bucket,
        Key: key
      }).promise();

      const metadata = await sharp(imageObject.Body).metadata();
      
      return {
        width: metadata.width,
        height: metadata.height,
        format: metadata.format,
        size: imageObject.ContentLength,
        density: metadata.density,
        hasAlpha: metadata.hasAlpha,
        orientation: metadata.orientation
      };
    } catch (error) {
      console.error(`Error getting image metadata ${key}:`, error);
      throw error;
    }
  }
}

module.exports = new ImageService();
```

#### 2-6. アップロードハンドラー

```javascript
// src/handlers/upload.js
const s3Service = require('../services/s3Service');
const imageService = require('../services/imageService');
const { createResponse, createErrorResponse } = require('../utils/response');

// プリサインドURL生成
exports.generateUploadUrl = async (event) => {
  try {
    const body = JSON.parse(event.body);
    const { fileName, contentType, userId } = body;

    if (!fileName || !contentType || !userId) {
      return createErrorResponse(400, 'fileName, contentType, and userId are required');
    }

    const result = await s3Service.generateUploadUrl(fileName, contentType, userId);
    
    return createResponse(200, {
      message: 'Upload URL generated successfully',
      ...result
    });
  } catch (error) {
    console.error('Generate upload URL error:', error);
    return createErrorResponse(400, error.message);
  }
};

// プリサインドPOST生成
exports.generateUploadPost = async (event) => {
  try {
    const body = JSON.parse(event.body);
    const { fileName, contentType, userId } = body;

    if (!fileName || !contentType || !userId) {
      return createErrorResponse(400, 'fileName, contentType, and userId are required');
    }

    const result = await s3Service.generateUploadPost(fileName, contentType, userId);
    
    return createResponse(200, {
      message: 'Upload POST data generated successfully',
      ...result
    });
  } catch (error) {
    console.error('Generate upload POST error:', error);
    return createErrorResponse(400, error.message);
  }
};

// アップロード完了通知
exports.uploadComplete = async (event) => {
  try {
    const body = JSON.parse(event.body);
    const { key, fileName, userId } = body;

    if (!key || !fileName || !userId) {
      return createErrorResponse(400, 'key, fileName, and userId are required');
    }

    // ファイルの存在確認
    const exists = await s3Service.fileExists(process.env.UPLOAD_BUCKET, key);
    if (!exists) {
      return createErrorResponse(404, 'Uploaded file not found');
    }

    // ファイル情報取得
    const fileInfo = await s3Service.getFileInfo(process.env.UPLOAD_BUCKET, key);

    return createResponse(200, {
      message: 'Upload completed successfully',
      file: {
        key,
        fileName,
        size: fileInfo.size,
        contentType: fileInfo.contentType,
        uploadedAt: fileInfo.lastModified
      }
    });
  } catch (error) {
    console.error('Upload complete error:', error);
    return createErrorResponse(500, 'Internal server error');
  }
};

// ファイル削除
exports.deleteFile = async (event) => {
  try {
    const { key } = event.pathParameters;
    const body = JSON.parse(event.body || '{}');
    const { userId } = body;

    if (!key || !userId) {
      return createErrorResponse(400, 'key and userId are required');
    }

    // 権限チェック（ユーザーが自分のファイルのみ削除可能）
    if (!key.startsWith(`uploads/${userId}/`)) {
      return createErrorResponse(403, 'Permission denied');
    }

    // 元ファイル削除
    await s3Service.deleteFile(process.env.UPLOAD_BUCKET, key);

    // 処理済みファイルも削除
    const processedKeys = Object.keys(UPLOAD_CONFIG.resizeSizes).map(size => 
      FileValidator.generateProcessedFileName(key, size, 'webp')
    );
    
    await s3Service.deleteFiles(process.env.PROCESSED_BUCKET, processedKeys);

    return createResponse(200, {
      message: 'File deleted successfully',
      deletedFiles: [key, ...processedKeys]
    });
  } catch (error) {
    console.error('Delete file error:', error);
    if (error.statusCode === 404) {
      return createErrorResponse(404, 'File not found');
    }
    return createErrorResponse(500, 'Internal server error');
  }
};

// ファイル一覧取得
exports.listFiles = async (event) => {
  try {
    const { userId } = event.pathParameters;
    const limit = parseInt(event.queryStringParameters?.limit || '20');
    const marker = event.queryStringParameters?.marker;

    const params = {
      Bucket: process.env.UPLOAD_BUCKET,
      Prefix: `uploads/${userId}/`,
      MaxKeys: limit
    };

    if (marker) {
      params.Marker = marker;
    }

    const result = await s3.listObjects(params).promise();
    
    const files = result.Contents.map(file => ({
      key: file.Key,
      size: file.Size,
      lastModified: file.LastModified,
      etag: file.ETag
    }));

    return createResponse(200, {
      files,
      isTruncated: result.IsTruncated,
      nextMarker: result.NextMarker
    });
  } catch (error) {
    console.error('List files error:', error);
    return createErrorResponse(500, 'Internal server error');
  }
};
```

#### 2-7. 画像処理Lambda

```javascript
// src/handlers/imageProcessor.js
const imageService = require('../services/imageService');

exports.processImage = async (event) => {
  try {
    console.log('Image processing triggered:', JSON.stringify(event, null, 2));

    // S3イベントから情報を取得
    for (const record of event.Records) {
      if (record.eventSource === 'aws:s3' && record.eventName.startsWith('ObjectCreated')) {
        const bucket = record.s3.bucket.name;
        const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

        console.log(`Processing image: s3://${bucket}/${key}`);

        // 画像処理実行
        const result = await imageService.processImage(bucket, key);

        console.log('Image processing completed:', result);

        // 処理結果をイベントとして発信（オプション）
        // await publishProcessingResult(result);
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Image processing completed successfully'
      })
    };
  } catch (error) {
    console.error('Image processing error:', error);
    throw error;
  }
};

// 処理結果をSNSやSQSに送信（オプション）
async function publishProcessingResult(result) {
  // 実装は次のセクションで追加
  console.log('Publishing processing result:', result);
}
```

### Step 3: フロントエンド実装

#### 3-1. FileUpload コンポーネント

```jsx
// frontend/src/components/FileUpload.jsx
import React, { useState, useRef, useCallback } from 'react';
import { Card, Button, Alert, ProgressBar, ListGroup } from 'react-bootstrap';
import { uploadApi } from '../services/uploadApi';

const FileUpload = ({ onUploadSuccess, maxFiles = 5, accept = "image/*" }) => {
  const [files, setFiles] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [error, setError] = useState('');
  const fileInputRef = useRef(null);

  const handleFileSelect = useCallback((selectedFiles) => {
    const newFiles = Array.from(selectedFiles).slice(0, maxFiles);
    
    // ファイル検証
    const validFiles = newFiles.filter(file => {
      if (!file.type.startsWith('image/')) {
        setError('Only image files are allowed');
        return false;
      }
      if (file.size > 10 * 1024 * 1024) {
        setError('File size must be less than 10MB');
        return false;
      }
      return true;
    });

    // プレビュー用URL生成
    const filesWithPreview = validFiles.map(file => ({
      file,
      id: Math.random().toString(36).substr(2, 9),
      preview: URL.createObjectURL(file),
      progress: 0,
      status: 'pending', // pending, uploading, completed, error
      uploadedUrl: null
    }));

    setFiles(prev => [...prev, ...filesWithPreview].slice(0, maxFiles));
    setError('');
  }, [maxFiles]);

  const handleDrop = useCallback((e) => {
    e.preventDefault();
    setDragOver(false);
    handleFileSelect(e.dataTransfer.files);
  }, [handleFileSelect]);

  const handleDragOver = useCallback((e) => {
    e.preventDefault();
    setDragOver(true);
  }, []);

  const handleDragLeave = useCallback((e) => {
    e.preventDefault();
    setDragOver(false);
  }, []);

  const removeFile = (id) => {
    setFiles(prev => {
      const updated = prev.filter(f => f.id !== id);
      // プレビューURLを解放
      const removed = prev.find(f => f.id === id);
      if (removed?.preview) {
        URL.revokeObjectURL(removed.preview);
      }
      return updated;
    });
  };

  const uploadFile = async (fileData) => {
    try {
      // プリサインドURL取得
      const uploadInfo = await uploadApi.generateUploadUrl(
        fileData.file.name,
        fileData.file.type,
        'demo-user' // 実際は認証システムから取得
      );

      // ファイルアップロード（プログレス付き）
      await uploadApi.uploadFile(uploadInfo.uploadUrl, fileData.file, (progress) => {
        setFiles(prev => prev.map(f => 
          f.id === fileData.id 
            ? { ...f, progress, status: 'uploading' }
            : f
        ));
      });

      // アップロード完了通知
      await uploadApi.uploadComplete(
        uploadInfo.key,
        fileData.file.name,
        'demo-user'
      );

      return uploadInfo.key;
    } catch (error) {
      console.error('Upload error:', error);
      throw error;
    }
  };

  const handleUploadAll = async () => {
    setUploading(true);
    const pendingFiles = files.filter(f => f.status === 'pending');

    try {
      const uploadPromises = pendingFiles.map(async (fileData) => {
        try {
          const uploadedKey = await uploadFile(fileData);
          
          setFiles(prev => prev.map(f => 
            f.id === fileData.id 
              ? { 
                  ...f, 
                  status: 'completed', 
                  progress: 100,
                  uploadedKey 
                }
              : f
          ));

          return { fileData, uploadedKey };
        } catch (error) {
          setFiles(prev => prev.map(f => 
            f.id === fileData.id 
              ? { ...f, status: 'error', progress: 0 }
              : f
          ));
          throw error;
        }
      });

      const results = await Promise.allSettled(uploadPromises);
      const successful = results
        .filter(r => r.status === 'fulfilled')
        .map(r => r.value);

      if (successful.length > 0) {
        onUploadSuccess?.(successful);
      }

      const failed = results.filter(r => r.status === 'rejected');
      if (failed.length > 0) {
        setError(`${failed.length} files failed to upload`);
      }

    } catch (error) {
      setError('Upload failed: ' + error.message);
    } finally {
      setUploading(false);
    }
  };

  const getStatusVariant = (status) => {
    switch (status) {
      case 'completed': return 'success';
      case 'error': return 'danger';
      case 'uploading': return 'primary';
      default: return 'secondary';
    }
  };

  return (
    <Card className="mb-4">
      <Card.Body>
        <h5>Upload Images</h5>
        
        {error && <Alert variant="danger">{error}</Alert>}

        {/* ドロップゾーン */}
        <div
          className={`border-2 border-dashed p-4 text-center mb-3 ${
            dragOver ? 'border-primary bg-light' : 'border-secondary'
          }`}
          onDrop={handleDrop}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          style={{ cursor: 'pointer' }}
          onClick={() => fileInputRef.current?.click()}
        >
          <div className="d-flex flex-column align-items-center">
            <i className="bi bi-cloud-upload fs-2 text-muted mb-2"></i>
            <p className="mb-2">
              Drag & drop images here, or click to select
            </p>
            <small className="text-muted">
              Max {maxFiles} files, up to 10MB each
            </small>
          </div>
        </div>

        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept={accept}
          onChange={(e) => handleFileSelect(e.target.files)}
          style={{ display: 'none' }}
        />

        {/* ファイル一覧 */}
        {files.length > 0 && (
          <div className="mb-3">
            <h6>Selected Files ({files.length}/{maxFiles})</h6>
            <ListGroup>
              {files.map((fileData) => (
                <ListGroup.Item key={fileData.id} className="d-flex align-items-center">
                  <img
                    src={fileData.preview}
                    alt="Preview"
                    className="me-3"
                    style={{ width: '50px', height: '50px', objectFit: 'cover' }}
                  />
                  
                  <div className="flex-grow-1">
                    <div className="d-flex justify-content-between align-items-center mb-1">
                      <span className="fw-bold">{fileData.file.name}</span>
                      <small className="text-muted">
                        {(fileData.file.size / 1024 / 1024).toFixed(2)} MB
                      </small>
                    </div>
                    
                    {fileData.status === 'uploading' && (
                      <ProgressBar 
                        now={fileData.progress} 
                        variant={getStatusVariant(fileData.status)}
                        style={{ height: '8px' }}
                      />
                    )}
                    
                    <div className="d-flex justify-content-between align-items-center mt-1">
                      <small className={`text-${getStatusVariant(fileData.status)}`}>
                        {fileData.status.charAt(0).toUpperCase() + fileData.status.slice(1)}
                      </small>
                      
                      {fileData.status === 'pending' && (
                        <Button
                          variant="outline-danger"
                          size="sm"
                          onClick={() => removeFile(fileData.id)}
                        >
                          Remove
                        </Button>
                      )}
                    </div>
                  </div>
                </ListGroup.Item>
              ))}
            </ListGroup>
          </div>
        )}

        {/* アップロードボタン */}
        {files.some(f => f.status === 'pending') && (
          <div className="d-flex justify-content-between">
            <Button
              variant="outline-secondary"
              onClick={() => setFiles([])}
              disabled={uploading}
            >
              Clear All
            </Button>
            
            <Button
              variant="primary"
              onClick={handleUploadAll}
              disabled={uploading || files.length === 0}
            >
              {uploading ? 'Uploading...' : `Upload ${files.filter(f => f.status === 'pending').length} Files`}
            </Button>
          </div>
        )}
      </Card.Body>
    </Card>
  );
};

export default FileUpload;
```

#### 3-2. ImageGallery コンポーネント

```jsx
// frontend/src/components/ImageGallery.jsx
import React, { useState } from 'react';
import { Modal, Carousel } from 'react-bootstrap';

const ImageGallery = ({ images, onImageClick }) => {
  const [showModal, setShowModal] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);

  const handleImageClick = (index) => {
    setCurrentIndex(index);
    setShowModal(true);
    onImageClick?.(images[index]);
  };

  const getResponsiveImageUrl = (image, size = 'medium') => {
    if (image.processed) {
      const processedImage = image.processed.find(p => p.sizeName === size);
      return processedImage?.url || image.url;
    }
    return image.url;
  };

  if (!images || images.length === 0) {
    return null;
  }

  return (
    <>
      <div className="row g-2 mb-3">
        {images.map((image, index) => (
          <div key={index} className="col-6 col-md-4 col-lg-3">
            <div 
              className="position-relative"
              style={{ paddingBottom: '100%', cursor: 'pointer' }}
              onClick={() => handleImageClick(index)}
            >
              <img
                src={getResponsiveImageUrl(image, 'small')}
                alt={`Image ${index + 1}`}
                className="position-absolute top-0 start-0 w-100 h-100 rounded"
                style={{ 
                  objectFit: 'cover',
                  transition: 'transform 0.2s'
                }}
                onMouseEnter={(e) => e.target.style.transform = 'scale(1.05)'}
                onMouseLeave={(e) => e.target.style.transform = 'scale(1)'}
                loading="lazy"
              />
            </div>
          </div>
        ))}
      </div>

      {/* モーダル表示 */}
      <Modal 
        show={showModal} 
        onHide={() => setShowModal(false)}
        size="lg"
        centered
      >
        <Modal.Body className="p-0">
          <Carousel 
            activeIndex={currentIndex} 
            onSelect={setCurrentIndex}
            controls={images.length > 1}
            indicators={images.length > 1}
          >
            {images.map((image, index) => (
              <Carousel.Item key={index}>
                <img
                  src={getResponsiveImageUrl(image, 'large')}
                  alt={`Image ${index + 1}`}
                  className="d-block w-100"
                  style={{ maxHeight: '70vh', objectFit: 'contain' }}
                />
              </Carousel.Item>
            ))}
          </Carousel>
        </Modal.Body>
      </Modal>
    </>
  );
};

export default ImageGallery;
```

#### 3-3. アップロードAPI サービス

```javascript
// frontend/src/services/uploadApi.js
const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || 'https://your-api-gateway-url';

class UploadAPI {
  async request(endpoint, options = {}) {
    const url = `${API_BASE_URL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    };

    const response = await fetch(url, config);
    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || `HTTP error! status: ${response.status}`);
    }

    return data;
  }

  // プリサインドURL取得
  async generateUploadUrl(fileName, contentType, userId) {
    return await this.request('/upload/url', {
      method: 'POST',
      body: JSON.stringify({
        fileName,
        contentType,
        userId
      })
    });
  }

  // ファイルアップロード（プログレス付き）
  async uploadFile(uploadUrl, file, onProgress) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      // プログレス監視
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          const progress = (e.loaded / e.total) * 100;
          onProgress?.(progress);
        }
      });

      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve();
        } else {
          reject(new Error(`Upload failed with status: ${xhr.status}`));
        }
      });

      xhr.addEventListener('error', () => {
        reject(new Error('Upload failed'));
      });

      xhr.open('PUT', uploadUrl);
      xhr.setRequestHeader('Content-Type', file.type);
      xhr.send(file);
    });
  }

  // アップロード完了通知
  async uploadComplete(key, fileName, userId) {
    return await this.request('/upload/complete', {
      method: 'POST',
      body: JSON.stringify({
        key,
        fileName,
        userId
      })
    });
  }

  // ファイル削除
  async deleteFile(key, userId) {
    return await this.request(`/upload/${encodeURIComponent(key)}`, {
      method: 'DELETE',
      body: JSON.stringify({ userId })
    });
  }

  // ファイル一覧取得
  async listFiles(userId, limit = 20, marker = null) {
    let endpoint = `/upload/list/${userId}?limit=${limit}`;
    if (marker) {
      endpoint += `&marker=${encodeURIComponent(marker)}`;
    }
    return await this.request(endpoint);
  }
}

export const uploadApi = new UploadAPI();
```

### Step 4: CloudFormation テンプレート

CloudFormationテンプレートは別ファイルで実装済みです。

### Step 5: テストと動作確認

#### 5-1. バックエンドテスト

```javascript
// backend/tests/upload.test.js
const s3Service = require('../src/services/s3Service');
const FileValidator = require('../src/utils/fileValidator');

describe('FileValidator', () => {
  test('should validate file correctly', () => {
    const validFile = {
      name: 'test.jpg',
      type: 'image/jpeg',
      size: 1024 * 1024 // 1MB
    };

    const result = FileValidator.validateFile(validFile);
    expect(result.isValid).toBe(true);
  });

  test('should reject oversized file', () => {
    const oversizedFile = {
      name: 'huge.jpg',
      type: 'image/jpeg',
      size: 15 * 1024 * 1024 // 15MB
    };

    const result = FileValidator.validateFile(oversizedFile);
    expect(result.isValid).toBe(false);
    expect(result.errors[0]).toContain('File size exceeds limit');
  });
});

describe('S3Service', () => {
  test('should generate upload URL', async () => {
    // モック実装
    const result = await s3Service.generateUploadUrl(
      'test.jpg',
      'image/jpeg',
      'test-user'
    );

    expect(result).toHaveProperty('uploadUrl');
    expect(result).toHaveProperty('key');
    expect(result.key).toContain('test-user');
  });
});
```

#### 5-2. フロントエンドテスト

```javascript
// frontend/src/components/__tests__/FileUpload.test.js
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import FileUpload from '../FileUpload';

describe('FileUpload', () => {
  test('renders upload area', () => {
    render(<FileUpload />);
    expect(screen.getByText(/drag & drop images here/i)).toBeInTheDocument();
  });

  test('handles file selection', () => {
    const mockOnUploadSuccess = jest.fn();
    render(<FileUpload onUploadSuccess={mockOnUploadSuccess} />);

    const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
    const input = screen.getByRole('button', { hidden: true });
    
    fireEvent.change(input, { target: { files: [file] } });
    
    expect(screen.getByText('test.jpg')).toBeInTheDocument();
  });
});
```

### Step 6: デプロイと動作確認

```bash
# バックエンドデプロイ
aws cloudformation deploy \
  --template-file cloudformation/file-upload.yaml \
  --stack-name sns-file-upload \
  --capabilities CAPABILITY_IAM

# フロントエンド環境設定
echo "REACT_APP_UPLOAD_API_URL=https://your-upload-api-url" >> .env

# アップロードテスト
curl -X POST https://your-api-gateway-url/upload/url \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "test.jpg",
    "contentType": "image/jpeg",
    "userId": "test-user"
  }'
```

## API エンドポイント

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/upload/url` | プリサインドURL生成 |
| POST | `/upload/complete` | アップロード完了通知 |
| DELETE | `/upload/{key}` | ファイル削除 |
| GET | `/upload/list/{userId}` | ファイル一覧取得 |

## 次のステップ

ファイルアップロード機能が完成したら、**3.3-データベース発展**に進みます。

次のセクションでは、PostgreSQLを使った関係データベース設計を学び、より複雑なデータ構造を扱います。

## 学習時間: 2時間

- 設計・準備: 30分
- バックエンド実装: 60分
- フロントエンド実装: 45分
- テスト・確認: 15分