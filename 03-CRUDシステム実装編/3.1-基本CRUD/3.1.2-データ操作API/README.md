# 3.1.2 データ操作API

## 学習目標

このセクションでは、RESTful APIの設計原則に従った高性能なデータ操作APIを構築し、適切な検証・エラーハンドリング・ページネーション・キャッシュ戦略を実装して、スケーラブルなバックエンドサービスを開発します。

### 習得できるスキル
- RESTful API設計とベストプラクティス
- データバリデーションとサニタイゼーション
- エラーハンドリングと適切なHTTPステータスコード
- ページネーション・ソート・フィルタリング実装
- APIレスポンスキャッシュ戦略
- OpenAPI/Swagger による API ドキュメント生成

## 前提知識

### 必須の知識
- REST API の基本概念とHTTPメソッド
- JSON データ形式の理解
- DynamoDB の基本操作（2.3.2セクション完了）
- Lambda 関数開発（1.2.3セクション完了）

### あると望ましい知識
- API設計パターンの理解
- データベース最適化技術
- キャッシュ戦略の知識
- API セキュリティベストプラクティス

## アーキテクチャ概要

### 高性能データAPI アーキテクチャ

```
                    ┌─────────────────────┐
                    │   Client Apps       │
                    │ (Web/Mobile/Third-  │
                    │  Party Integrations)│
                    └─────────┬───────────┘
                              │
                    ┌─────────┼───────────┐
                    │         │           │
                    ▼         ▼           ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   CloudFront    │ │   WAF    │ │   Route 53      │
          │   (API Cache)   │ │(Security)│ │  (DNS/Health)   │
          └─────────┬───────┘ └────┬─────┘ └─────────┬───────┘
                    │              │                 │
                    └──────────────┼─────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │                 API Gateway                             │
          │                                                         │
          │  ┌─────────────────────────────────────────────────┐   │
          │  │              Request Processing                 │   │
          │  │                                                  │   │
          │  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │   │
          │  │  │   Rate      │  │ Request     │  │Response  │ │   │
          │  │  │ Limiting    │  │Validation   │  │Transform │ │   │
          │  │  │             │  │             │  │          │ │   │
          │  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │┌────────┐│ │   │
          │  │  │ │Throttle │ │  │ │Schema   │ │  ││JSON    ││ │   │
          │  │  │ │Rules    │ │  │ │Validation│ │  ││Format  ││ │   │
          │  │  │ └─────────┘ │  │ └─────────┘ │  │└────────┘│ │   │
          │  │  └─────────────┘  └─────────────┘  └──────────┘ │   │
          │  └─────────────────────────────────────────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                                   ▼
          ┌─────────────────────────────────────────────────────────┐
          │               Lambda Functions                          │
          │              (Business Logic)                           │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │   CRUD      │  │   Search    │  │   Batch     │   │
          │  │  Functions  │  │  Functions  │  │ Operations  │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││Create    │ │  ││Query     │ │  ││Bulk      │ │   │
          │  ││Read      │ │  ││Filter    │ │  ││Import    │ │   │
          │  ││Update    │ │  ││Sort      │ │  ││Export    │ │   │
          │  ││Delete    │ │  ││Paginate  │ │  ││Validate  │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
          ┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
          │   DynamoDB      │ │ElastiCache│ │   S3 Bucket     │
          │  (Primary DB)   │ │(Response  │ │ (File Storage)  │
          │                 │ │ Cache)    │ │                 │
          │ ┌─────────────┐ │ │┌────────┐ │ │ ┌─────────────┐ │
          │ │  Main       │ │ ││Redis   │ │ │ │   Uploads   │ │
          │ │  Table      │ │ ││Cluster │ │ │ │   Exports   │ │
          │ │             │ │ │└────────┘ │ │ │   Assets    │ │
          │ │ ┌─────────┐ │ │ │          │ │ │ └─────────────┘ │
          │ │ │Users    │ │ │ │┌────────┐ │ │ └─────────────────┘
          │ │ │Products │ │ │ ││TTL     │ │ │ 
          │ │ │Orders   │ │ │ ││Keys    │ │ │ 
          │ │ │Reviews  │ │ │ │└────────┘ │ │ 
          │ │ └─────────┘ │ │ └──────────┘ │ 
          │ └─────────────┘ │              │ 
          └─────────────────┘              │ 
                    │                      │ 
                    ▼                      ▼ 
          ┌─────────────────────────────────────────────────────────┐
          │              Monitoring & Analytics                     │
          │                                                         │
          │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
          │  │ CloudWatch  │  │   X-Ray     │  │   Kinesis   │   │
          │  │  Metrics    │  │  Tracing    │  │ Analytics   │   │
          │  │             │  │             │  │             │   │
          │  │┌──────────┐ │  │┌──────────┐ │  │┌──────────┐ │   │
          │  ││API       │ │  ││Request   │ │  ││Usage     │ │   │
          │  ││Metrics   │ │  ││Traces    │ │  ││Patterns  │ │   │
          │  ││Alarms    │ │  ││Errors    │ │  ││Reports   │ │   │
          │  │└──────────┘ │  │└──────────┘ │  │└──────────┘ │   │
          │  └─────────────┘  └─────────────┘  └─────────────┘   │
          └─────────────────────────────────────────────────────────┘
```

### 主要コンポーネント
- **API Gateway**: リクエスト処理・バリデーション・レスポンス変換
- **Lambda Functions**: ビジネスロジック実装
- **DynamoDB**: 高性能データストレージ
- **ElastiCache**: レスポンスキャッシュ
- **CloudWatch**: 監視・ログ・メトリクス
- **X-Ray**: 分散トレーシング

## ハンズオン手順

### ステップ1: データモデルと API 設計

1. **OpenAPI 仕様書の作成**
```yaml
# docs/api-specification.yaml
openapi: 3.0.3
info:
  title: Data Operations API
  description: 'Comprehensive CRUD API with advanced features'
  version: 1.0.0
  contact:
    name: API Support
    email: api-support@example.com
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.example.com/v1
    description: Production server
  - url: https://api-dev.example.com/v1
    description: Development server

paths:
  /products:
    get:
      summary: Get products with filtering, sorting, and pagination
      description: Retrieve a list of products with advanced query capabilities
      parameters:
        - $ref: '#/components/parameters/LimitParam'
        - $ref: '#/components/parameters/OffsetParam'
        - $ref: '#/components/parameters/SortParam'
        - $ref: '#/components/parameters/OrderParam'
        - name: category
          in: query
          schema:
            type: string
          description: Filter by category
        - name: price_min
          in: query
          schema:
            type: number
            minimum: 0
          description: Minimum price filter
        - name: price_max
          in: query
          schema:
            type: number
            minimum: 0
          description: Maximum price filter
        - name: search
          in: query
          schema:
            type: string
            minLength: 2
            maxLength: 100
          description: Search term for name/description
        - name: status
          in: query
          schema:
            type: string
            enum: [ACTIVE, INACTIVE, DISCONTINUED]
          description: Filter by product status
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductListResponse'
        '400':
          $ref: '#/components/responses/BadRequest'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '500':
          $ref: '#/components/responses/InternalError'
    
    post:
      summary: Create a new product
      description: Create a new product with validation
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductCreateRequest'
      responses:
        '201':
          description: Product created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductResponse'
        '400':
          $ref: '#/components/responses/BadRequest'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '422':
          $ref: '#/components/responses/ValidationError'

  /products/{productId}:
    parameters:
      - $ref: '#/components/parameters/ProductIdParam'
    
    get:
      summary: Get product by ID
      responses:
        '200':
          description: Product found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductResponse'
        '404':
          $ref: '#/components/responses/NotFound'
    
    put:
      summary: Update product
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ProductUpdateRequest'
      responses:
        '200':
          description: Product updated successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ProductResponse'
        '404':
          $ref: '#/components/responses/NotFound'
        '422':
          $ref: '#/components/responses/ValidationError'
    
    delete:
      summary: Delete product
      responses:
        '204':
          description: Product deleted successfully
        '404':
          $ref: '#/components/responses/NotFound'

  /products/batch:
    post:
      summary: Batch operations on products
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/BatchOperationRequest'
      responses:
        '200':
          description: Batch operation completed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BatchOperationResponse'

components:
  parameters:
    ProductIdParam:
      name: productId
      in: path
      required: true
      schema:
        type: string
        pattern: '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$'
      description: Product UUID
    
    LimitParam:
      name: limit
      in: query
      schema:
        type: integer
        minimum: 1
        maximum: 100
        default: 20
      description: Number of items to return
    
    OffsetParam:
      name: offset
      in: query
      schema:
        type: integer
        minimum: 0
        default: 0
      description: Number of items to skip
    
    SortParam:
      name: sort
      in: query
      schema:
        type: string
        enum: [name, price, createdAt, updatedAt]
        default: createdAt
      description: Field to sort by
    
    OrderParam:
      name: order
      in: query
      schema:
        type: string
        enum: [asc, desc]
        default: desc
      description: Sort order

  schemas:
    Product:
      type: object
      properties:
        productId:
          type: string
          format: uuid
          description: Unique product identifier
        name:
          type: string
          minLength: 1
          maxLength: 200
          description: Product name
        description:
          type: string
          maxLength: 2000
          description: Product description
        price:
          type: number
          minimum: 0
          multipleOf: 0.01
          description: Product price
        category:
          type: string
          minLength: 1
          maxLength: 100
          description: Product category
        status:
          type: string
          enum: [ACTIVE, INACTIVE, DISCONTINUED]
          description: Product status
        inventory:
          type: integer
          minimum: 0
          description: Available inventory
        images:
          type: array
          items:
            type: string
            format: uri
          maxItems: 10
          description: Product image URLs
        tags:
          type: array
          items:
            type: string
          maxItems: 20
          description: Product tags
        metadata:
          type: object
          description: Additional product metadata
        createdAt:
          type: string
          format: date-time
          description: Creation timestamp
        updatedAt:
          type: string
          format: date-time
          description: Last update timestamp
      required:
        - productId
        - name
        - price
        - category
        - status

    ProductCreateRequest:
      type: object
      properties:
        name:
          type: string
          minLength: 1
          maxLength: 200
        description:
          type: string
          maxLength: 2000
        price:
          type: number
          minimum: 0
          multipleOf: 0.01
        category:
          type: string
          minLength: 1
          maxLength: 100
        inventory:
          type: integer
          minimum: 0
          default: 0
        images:
          type: array
          items:
            type: string
            format: uri
          maxItems: 10
        tags:
          type: array
          items:
            type: string
          maxItems: 20
        metadata:
          type: object
      required:
        - name
        - price
        - category

    ProductResponse:
      allOf:
        - $ref: '#/components/schemas/Product'
        - type: object
          properties:
            links:
              type: object
              properties:
                self:
                  type: string
                  format: uri
                edit:
                  type: string
                  format: uri
                delete:
                  type: string
                  format: uri

    ProductListResponse:
      type: object
      properties:
        data:
          type: array
          items:
            $ref: '#/components/schemas/ProductResponse'
        pagination:
          $ref: '#/components/schemas/PaginationInfo'
        filters:
          type: object
          description: Applied filters
        sorting:
          type: object
          properties:
            field:
              type: string
            order:
              type: string
      required:
        - data
        - pagination

    PaginationInfo:
      type: object
      properties:
        limit:
          type: integer
        offset:
          type: integer
        total:
          type: integer
        hasNext:
          type: boolean
        hasPrevious:
          type: boolean
        links:
          type: object
          properties:
            first:
              type: string
              format: uri
            previous:
              type: string
              format: uri
            next:
              type: string
              format: uri
            last:
              type: string
              format: uri

  responses:
    BadRequest:
      description: Bad request
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    
    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    
    NotFound:
      description: Resource not found
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    
    ValidationError:
      description: Validation error
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ValidationErrorResponse'

  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

security:
  - BearerAuth: []
```

### ステップ2: データバリデーション層の実装

1. **バリデーションミドルウェア**
```javascript
// src/middleware/validation.js
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

class ValidationMiddleware {
    constructor() {
        this.ajv = new Ajv({ 
            allErrors: true,
            removeAdditional: true,
            useDefaults: true,
            coerceTypes: true
        });
        addFormats(this.ajv);
        
        // カスタムフォーマット定義
        this.ajv.addFormat('uuid', {
            type: 'string',
            validate: (str) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)
        });
        
        this.ajv.addFormat('slug', {
            type: 'string',
            validate: (str) => /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(str)
        });
        
        // スキーマ定義
        this.schemas = {
            productCreate: {
                type: 'object',
                properties: {
                    name: { 
                        type: 'string', 
                        minLength: 1, 
                        maxLength: 200,
                        pattern: '^[^<>]*$' // XSS対策
                    },
                    description: { 
                        type: 'string', 
                        maxLength: 2000,
                        pattern: '^[^<>]*$'
                    },
                    price: { 
                        type: 'number', 
                        minimum: 0,
                        multipleOf: 0.01
                    },
                    category: { 
                        type: 'string',
                        minLength: 1,
                        maxLength: 100,
                        format: 'slug'
                    },
                    inventory: { 
                        type: 'integer', 
                        minimum: 0,
                        default: 0
                    },
                    images: {
                        type: 'array',
                        items: { 
                            type: 'string', 
                            format: 'uri',
                            pattern: '^https://'
                        },
                        maxItems: 10,
                        uniqueItems: true
                    },
                    tags: {
                        type: 'array',
                        items: { 
                            type: 'string',
                            minLength: 1,
                            maxLength: 50,
                            pattern: '^[a-zA-Z0-9-_]+$'
                        },
                        maxItems: 20,
                        uniqueItems: true
                    },
                    metadata: { 
                        type: 'object',
                        additionalProperties: true
                    }
                },
                required: ['name', 'price', 'category'],
                additionalProperties: false
            },
            
            productUpdate: {
                type: 'object',
                properties: {
                    name: { 
                        type: 'string', 
                        minLength: 1, 
                        maxLength: 200,
                        pattern: '^[^<>]*$'
                    },
                    description: { 
                        type: 'string', 
                        maxLength: 2000,
                        pattern: '^[^<>]*$'
                    },
                    price: { 
                        type: 'number', 
                        minimum: 0,
                        multipleOf: 0.01
                    },
                    category: { 
                        type: 'string',
                        minLength: 1,
                        maxLength: 100,
                        format: 'slug'
                    },
                    inventory: { 
                        type: 'integer', 
                        minimum: 0
                    },
                    status: {
                        type: 'string',
                        enum: ['ACTIVE', 'INACTIVE', 'DISCONTINUED']
                    },
                    images: {
                        type: 'array',
                        items: { 
                            type: 'string', 
                            format: 'uri',
                            pattern: '^https://'
                        },
                        maxItems: 10,
                        uniqueItems: true
                    },
                    tags: {
                        type: 'array',
                        items: { 
                            type: 'string',
                            minLength: 1,
                            maxLength: 50,
                            pattern: '^[a-zA-Z0-9-_]+$'
                        },
                        maxItems: 20,
                        uniqueItems: true
                    },
                    metadata: { 
                        type: 'object',
                        additionalProperties: true
                    }
                },
                additionalProperties: false,
                minProperties: 1
            },
            
            queryParams: {
                type: 'object',
                properties: {
                    limit: { 
                        type: 'integer', 
                        minimum: 1, 
                        maximum: 100, 
                        default: 20 
                    },
                    offset: { 
                        type: 'integer', 
                        minimum: 0, 
                        default: 0 
                    },
                    sort: { 
                        type: 'string', 
                        enum: ['name', 'price', 'createdAt', 'updatedAt'],
                        default: 'createdAt'
                    },
                    order: { 
                        type: 'string', 
                        enum: ['asc', 'desc'],
                        default: 'desc'
                    },
                    category: { 
                        type: 'string',
                        format: 'slug'
                    },
                    price_min: { 
                        type: 'number', 
                        minimum: 0 
                    },
                    price_max: { 
                        type: 'number', 
                        minimum: 0 
                    },
                    search: { 
                        type: 'string', 
                        minLength: 2, 
                        maxLength: 100,
                        pattern: '^[^<>]*$'
                    },
                    status: {
                        type: 'string',
                        enum: ['ACTIVE', 'INACTIVE', 'DISCONTINUED']
                    }
                },
                additionalProperties: false
            }
        };
        
        // スキーマをコンパイル
        Object.keys(this.schemas).forEach(key => {
            this.schemas[key] = this.ajv.compile(this.schemas[key]);
        });
    }
    
    validate(schemaName, data) {
        const validator = this.schemas[schemaName];
        if (!validator) {
            throw new Error(`Schema ${schemaName} not found`);
        }
        
        const valid = validator(data);
        if (!valid) {
            const errors = this.formatErrors(validator.errors);
            return { valid: false, errors };
        }
        
        return { valid: true, data };
    }
    
    formatErrors(ajvErrors) {
        return ajvErrors.map(error => ({
            field: error.instancePath.replace('/', '') || error.params?.missingProperty || 'root',
            message: error.message,
            value: error.data,
            constraint: error.params
        }));
    }
    
    middleware(schemaName) {
        return (req, res, next) => {
            const data = req.method === 'GET' ? req.query : req.body;
            const result = this.validate(schemaName, data);
            
            if (!result.valid) {
                return res.status(422).json({
                    error: 'Validation Error',
                    message: 'The request data is invalid',
                    details: result.errors,
                    timestamp: new Date().toISOString()
                });
            }
            
            // バリデーション済みデータをセット
            if (req.method === 'GET') {
                req.validatedQuery = result.data;
            } else {
                req.validatedBody = result.data;
            }
            
            next();
        };
    }
    
    sanitizeHtml(str) {
        return str
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#x27;');
    }
    
    sanitizeObject(obj) {
        if (typeof obj === 'string') {
            return this.sanitizeHtml(obj);
        }
        
        if (Array.isArray(obj)) {
            return obj.map(item => this.sanitizeObject(item));
        }
        
        if (obj && typeof obj === 'object') {
            const sanitized = {};
            Object.keys(obj).forEach(key => {
                sanitized[key] = this.sanitizeObject(obj[key]);
            });
            return sanitized;
        }
        
        return obj;
    }
}

module.exports = new ValidationMiddleware();
```

### ステップ3: 高度なCRUD操作の実装

1. **Product API Lambda関数**
```javascript
// src/lambda/product-api.js
const AWS = require('aws-sdk');
const validator = require('../middleware/validation');
const { v4: uuidv4 } = require('uuid');

const dynamodb = new AWS.DynamoDB.DocumentClient();
const elasticache = new AWS.ElastiCache();

const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME;
const CACHE_CLUSTER_ENDPOINT = process.env.ELASTICACHE_ENDPOINT;

// Redis クライアント（簡易実装）
let redisClient = null;
if (CACHE_CLUSTER_ENDPOINT) {
    const redis = require('redis');
    redisClient = redis.createClient({
        host: CACHE_CLUSTER_ENDPOINT,
        port: 6379
    });
}

exports.handler = async (event) => {
    console.log('Request event:', JSON.stringify(event, null, 2));
    
    const { httpMethod, pathParameters, queryStringParameters, body } = event;
    const path = event.resource;
    
    try {
        // ルーティング
        switch (true) {
            case httpMethod === 'GET' && path === '/products':
                return await listProducts(queryStringParameters || {});
            case httpMethod === 'POST' && path === '/products':
                return await createProduct(JSON.parse(body || '{}'));
            case httpMethod === 'GET' && path === '/products/{productId}':
                return await getProduct(pathParameters.productId);
            case httpMethod === 'PUT' && path === '/products/{productId}':
                return await updateProduct(pathParameters.productId, JSON.parse(body || '{}'));
            case httpMethod === 'DELETE' && path === '/products/{productId}':
                return await deleteProduct(pathParameters.productId);
            case httpMethod === 'POST' && path === '/products/batch':
                return await batchOperation(JSON.parse(body || '{}'));
            default:
                return createResponse(404, { error: 'Not Found' });
        }
    } catch (error) {
        console.error('API Error:', error);
        
        // エラータイプに応じた適切なレスポンス
        if (error.name === 'ValidationError') {
            return createResponse(422, {
                error: 'Validation Error',
                message: error.message,
                details: error.details
            });
        }
        
        if (error.code === 'ConditionalCheckFailedException') {
            return createResponse(409, {
                error: 'Conflict',
                message: 'Resource already exists or has been modified'
            });
        }
        
        if (error.code === 'ResourceNotFoundException') {
            return createResponse(404, {
                error: 'Not Found',
                message: 'The requested resource was not found'
            });
        }
        
        return createResponse(500, {
            error: 'Internal Server Error',
            message: 'An unexpected error occurred',
            requestId: event.requestContext?.requestId
        });
    }
};

async function listProducts(queryParams) {
    // クエリパラメータバリデーション
    const validation = validator.validate('queryParams', queryParams);
    if (!validation.valid) {
        throw new ValidationError('Invalid query parameters', validation.errors);
    }
    
    const params = validation.data;
    const cacheKey = `products:${JSON.stringify(params)}`;
    
    // キャッシュ確認
    const cachedResult = await getFromCache(cacheKey);
    if (cachedResult) {
        return createResponse(200, cachedResult);
    }
    
    // DynamoDB クエリ構築
    const scanParams = {
        TableName: TABLE_NAME,
        FilterExpression: 'entityType = :entityType',
        ExpressionAttributeValues: {
            ':entityType': 'PRODUCT'
        },
        Limit: params.limit
    };
    
    // フィルタ条件追加
    if (params.category) {
        scanParams.FilterExpression += ' AND category = :category';
        scanParams.ExpressionAttributeValues[':category'] = params.category;
    }
    
    if (params.status) {
        scanParams.FilterExpression += ' AND #status = :status';
        scanParams.ExpressionAttributeNames = { '#status': 'status' };
        scanParams.ExpressionAttributeValues[':status'] = params.status;
    }
    
    if (params.price_min !== undefined) {
        scanParams.FilterExpression += ' AND price >= :priceMin';
        scanParams.ExpressionAttributeValues[':priceMin'] = params.price_min;
    }
    
    if (params.price_max !== undefined) {
        scanParams.FilterExpression += ' AND price <= :priceMax';
        scanParams.ExpressionAttributeValues[':priceMax'] = params.price_max;
    }
    
    if (params.search) {
        scanParams.FilterExpression += ' AND (contains(#name, :search) OR contains(description, :search))';
        scanParams.ExpressionAttributeNames = { 
            ...scanParams.ExpressionAttributeNames,
            '#name': 'name' 
        };
        scanParams.ExpressionAttributeValues[':search'] = params.search;
    }
    
    // オフセット実装（DynamoDBの制約により非効率だが、実用的な実装）
    let scannedItems = [];
    let lastEvaluatedKey = null;
    let totalScanned = 0;
    
    do {
        if (lastEvaluatedKey) {
            scanParams.ExclusiveStartKey = lastEvaluatedKey;
        }
        
        const result = await dynamodb.scan(scanParams).promise();
        scannedItems.push(...result.Items);
        lastEvaluatedKey = result.LastEvaluatedKey;
        totalScanned += result.Count;
        
    } while (lastEvaluatedKey && scannedItems.length < params.offset + params.limit);
    
    // ソート処理
    scannedItems.sort((a, b) => {
        const aValue = a[params.sort];
        const bValue = b[params.sort];
        
        if (params.order === 'asc') {
            return aValue > bValue ? 1 : -1;
        } else {
            return aValue < bValue ? 1 : -1;
        }
    });
    
    // ページネーション
    const paginatedItems = scannedItems.slice(params.offset, params.offset + params.limit);
    const total = scannedItems.length;
    
    // レスポンス構築
    const response = {
        data: paginatedItems.map(item => ({
            ...item,
            links: {
                self: `/products/${item.productId}`,
                edit: `/products/${item.productId}`,
                delete: `/products/${item.productId}`
            }
        })),
        pagination: {
            limit: params.limit,
            offset: params.offset,
            total: total,
            hasNext: params.offset + params.limit < total,
            hasPrevious: params.offset > 0,
            links: {
                first: buildPaginationUrl(params, 0),
                previous: params.offset > 0 ? buildPaginationUrl(params, Math.max(0, params.offset - params.limit)) : null,
                next: params.offset + params.limit < total ? buildPaginationUrl(params, params.offset + params.limit) : null,
                last: buildPaginationUrl(params, Math.floor(total / params.limit) * params.limit)
            }
        },
        filters: {
            category: params.category,
            status: params.status,
            priceRange: params.price_min || params.price_max ? {
                min: params.price_min,
                max: params.price_max
            } : null,
            search: params.search
        },
        sorting: {
            field: params.sort,
            order: params.order
        }
    };
    
    // キャッシュに保存（5分間）
    await setToCache(cacheKey, response, 300);
    
    return createResponse(200, response);
}

async function createProduct(productData) {
    // バリデーション
    const validation = validator.validate('productCreate', productData);
    if (!validation.valid) {
        throw new ValidationError('Invalid product data', validation.errors);
    }
    
    const sanitizedData = validator.sanitizeObject(validation.data);
    const productId = uuidv4();
    const timestamp = new Date().toISOString();
    
    const product = {
        PK: `PRODUCT#${productId}`,
        SK: 'METADATA',
        entityType: 'PRODUCT',
        productId: productId,
        ...sanitizedData,
        status: 'ACTIVE',
        createdAt: timestamp,
        updatedAt: timestamp,
        
        // GSI キー
        GSI1PK: `CATEGORY#${sanitizedData.category}`,
        GSI1SK: `PRODUCT#${timestamp}`,
        GSI2PK: `STATUS#ACTIVE`,
        GSI2SK: `PRODUCT#${productId}`
    };
    
    // DynamoDB 保存
    await dynamodb.put({
        TableName: TABLE_NAME,
        Item: product,
        ConditionExpression: 'attribute_not_exists(PK)'
    }).promise();
    
    // キャッシュクリア
    await clearCachePattern('products:*');
    
    const responseProduct = {
        ...product,
        links: {
            self: `/products/${productId}`,
            edit: `/products/${productId}`,
            delete: `/products/${productId}`
        }
    };
    
    // PK, SK, GSI キーを除去
    delete responseProduct.PK;
    delete responseProduct.SK;
    delete responseProduct.GSI1PK;
    delete responseProduct.GSI1SK;
    delete responseProduct.GSI2PK;
    delete responseProduct.GSI2SK;
    delete responseProduct.entityType;
    
    return createResponse(201, responseProduct);
}

async function getProduct(productId) {
    // UUID バリデーション
    if (!isValidUUID(productId)) {
        return createResponse(400, { error: 'Invalid product ID format' });
    }
    
    const cacheKey = `product:${productId}`;
    
    // キャッシュ確認
    const cachedProduct = await getFromCache(cacheKey);
    if (cachedProduct) {
        return createResponse(200, cachedProduct);
    }
    
    // DynamoDB から取得
    const result = await dynamodb.get({
        TableName: TABLE_NAME,
        Key: {
            PK: `PRODUCT#${productId}`,
            SK: 'METADATA'
        }
    }).promise();
    
    if (!result.Item) {
        return createResponse(404, { error: 'Product not found' });
    }
    
    const product = {
        ...result.Item,
        links: {
            self: `/products/${productId}`,
            edit: `/products/${productId}`,
            delete: `/products/${productId}`
        }
    };
    
    // 内部フィールド除去
    delete product.PK;
    delete product.SK;
    delete product.GSI1PK;
    delete product.GSI1SK;
    delete product.GSI2PK;
    delete product.GSI2SK;
    delete product.entityType;
    
    // キャッシュに保存（1時間）
    await setToCache(cacheKey, product, 3600);
    
    return createResponse(200, product);
}

async function updateProduct(productId, updateData) {
    // バリデーション
    if (!isValidUUID(productId)) {
        return createResponse(400, { error: 'Invalid product ID format' });
    }
    
    const validation = validator.validate('productUpdate', updateData);
    if (!validation.valid) {
        throw new ValidationError('Invalid update data', validation.errors);
    }
    
    const sanitizedData = validator.sanitizeObject(validation.data);
    const timestamp = new Date().toISOString();
    
    // 更新式構築
    const updateExpression = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {
        ':updatedAt': timestamp
    };
    
    Object.keys(sanitizedData).forEach(key => {
        updateExpression.push(`#${key} = :${key}`);
        expressionAttributeNames[`#${key}`] = key;
        expressionAttributeValues[`:${key}`] = sanitizedData[key];
    });
    
    updateExpression.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    
    // GSI キー更新（カテゴリ変更時）
    if (sanitizedData.category) {
        updateExpression.push('GSI1PK = :gsi1pk');
        expressionAttributeValues[':gsi1pk'] = `CATEGORY#${sanitizedData.category}`;
    }
    
    if (sanitizedData.status) {
        updateExpression.push('GSI2PK = :gsi2pk');
        expressionAttributeValues[':gsi2pk'] = `STATUS#${sanitizedData.status}`;
    }
    
    try {
        const result = await dynamodb.update({
            TableName: TABLE_NAME,
            Key: {
                PK: `PRODUCT#${productId}`,
                SK: 'METADATA'
            },
            UpdateExpression: `SET ${updateExpression.join(', ')}`,
            ExpressionAttributeNames: expressionAttributeNames,
            ExpressionAttributeValues: expressionAttributeValues,
            ConditionExpression: 'attribute_exists(PK)',
            ReturnValues: 'ALL_NEW'
        }).promise();
        
        // キャッシュクリア
        await clearCachePattern(`product:${productId}`);
        await clearCachePattern('products:*');
        
        const product = {
            ...result.Attributes,
            links: {
                self: `/products/${productId}`,
                edit: `/products/${productId}`,
                delete: `/products/${productId}`
            }
        };
        
        // 内部フィールド除去
        delete product.PK;
        delete product.SK;
        delete product.GSI1PK;
        delete product.GSI1SK;
        delete product.GSI2PK;
        delete product.GSI2SK;
        delete product.entityType;
        
        return createResponse(200, product);
    } catch (error) {
        if (error.code === 'ConditionalCheckFailedException') {
            return createResponse(404, { error: 'Product not found' });
        }
        throw error;
    }
}

async function deleteProduct(productId) {
    if (!isValidUUID(productId)) {
        return createResponse(400, { error: 'Invalid product ID format' });
    }
    
    try {
        await dynamodb.delete({
            TableName: TABLE_NAME,
            Key: {
                PK: `PRODUCT#${productId}`,
                SK: 'METADATA'
            },
            ConditionExpression: 'attribute_exists(PK)'
        }).promise();
        
        // キャッシュクリア
        await clearCachePattern(`product:${productId}`);
        await clearCachePattern('products:*');
        
        return createResponse(204, null);
    } catch (error) {
        if (error.code === 'ConditionalCheckFailedException') {
            return createResponse(404, { error: 'Product not found' });
        }
        throw error;
    }
}

async function batchOperation(batchData) {
    const { operation, items } = batchData;
    
    if (!operation || !items || !Array.isArray(items)) {
        return createResponse(400, { 
            error: 'Invalid batch operation data',
            required: ['operation', 'items']
        });
    }
    
    if (items.length > 25) {
        return createResponse(400, { 
            error: 'Batch size too large',
            maximum: 25,
            received: items.length
        });
    }
    
    const results = {
        operation: operation,
        total: items.length,
        successful: 0,
        failed: 0,
        results: []
    };
    
    switch (operation) {
        case 'CREATE':
            for (const item of items) {
                try {
                    const result = await createProduct(item);
                    results.results.push({
                        status: 'SUCCESS',
                        data: JSON.parse(result.body)
                    });
                    results.successful++;
                } catch (error) {
                    results.results.push({
                        status: 'FAILED',
                        error: error.message,
                        data: item
                    });
                    results.failed++;
                }
            }
            break;
            
        case 'UPDATE':
            for (const item of items) {
                try {
                    const { productId, ...updateData } = item;
                    const result = await updateProduct(productId, updateData);
                    results.results.push({
                        status: 'SUCCESS',
                        data: JSON.parse(result.body)
                    });
                    results.successful++;
                } catch (error) {
                    results.results.push({
                        status: 'FAILED',
                        error: error.message,
                        data: item
                    });
                    results.failed++;
                }
            }
            break;
            
        case 'DELETE':
            for (const productId of items) {
                try {
                    await deleteProduct(productId);
                    results.results.push({
                        status: 'SUCCESS',
                        productId: productId
                    });
                    results.successful++;
                } catch (error) {
                    results.results.push({
                        status: 'FAILED',
                        error: error.message,
                        productId: productId
                    });
                    results.failed++;
                }
            }
            break;
            
        default:
            return createResponse(400, { 
                error: 'Unsupported batch operation',
                supportedOperations: ['CREATE', 'UPDATE', 'DELETE']
            });
    }
    
    return createResponse(200, results);
}

// ヘルパー関数
function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
            'X-Request-ID': Date.now().toString()
        },
        body: body ? JSON.stringify(body) : null
    };
}

function isValidUUID(str) {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
}

function buildPaginationUrl(params, offset) {
    const query = new URLSearchParams({
        limit: params.limit,
        offset: offset,
        sort: params.sort,
        order: params.order
    });
    
    // フィルタパラメータ追加
    if (params.category) query.append('category', params.category);
    if (params.status) query.append('status', params.status);
    if (params.price_min) query.append('price_min', params.price_min);
    if (params.price_max) query.append('price_max', params.price_max);
    if (params.search) query.append('search', params.search);
    
    return `/products?${query.toString()}`;
}

// キャッシュ操作関数
async function getFromCache(key) {
    if (!redisClient) return null;
    
    try {
        const result = await redisClient.get(key);
        return result ? JSON.parse(result) : null;
    } catch (error) {
        console.error('Cache get error:', error);
        return null;
    }
}

async function setToCache(key, value, ttlSeconds) {
    if (!redisClient) return;
    
    try {
        await redisClient.setex(key, ttlSeconds, JSON.stringify(value));
    } catch (error) {
        console.error('Cache set error:', error);
    }
}

async function clearCachePattern(pattern) {
    if (!redisClient) return;
    
    try {
        const keys = await redisClient.keys(pattern);
        if (keys.length > 0) {
            await redisClient.del(keys);
        }
    } catch (error) {
        console.error('Cache clear error:', error);
    }
}

class ValidationError extends Error {
    constructor(message, details) {
        super(message);
        this.name = 'ValidationError';
        this.details = details;
    }
}
```

### ステップ4: API Gateway設定とCloudFormation

1. **API Gateway とLambda統合**
```yaml
# cloudformation/data-api-infrastructure.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Data Operations API with advanced features'

Parameters:
  ProjectName:
    Type: String
    Default: 'data-api'
  
  EnvironmentName:
    Type: String
    Default: 'dev'
    AllowedValues: [dev, staging, prod]

Conditions:
  IsProduction: !Equals [!Ref EnvironmentName, 'prod']

Resources:
  # API Gateway
  RestApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: !Sub '${ProjectName}-${EnvironmentName}-api'
      Description: 'Advanced Data Operations API'
      EndpointConfiguration:
        Types:
          - REGIONAL
      Policy:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal: '*'
            Action: execute-api:Invoke
            Resource: '*'
            Condition:
              IpAddress:
                aws:SourceIp: 
                  - '0.0.0.0/0'  # 本番では適切なIP制限を設定

  # API Gateway Request Validator
  RequestValidator:
    Type: AWS::ApiGateway::RequestValidator
    Properties:
      RestApiId: !Ref RestApi
      Name: 'request-validator'
      ValidateRequestBody: true
      ValidateRequestParameters: true

  # Products Resource
  ProductsResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref RestApi
      ParentId: !GetAtt RestApi.RootResourceId
      PathPart: 'products'

  # Single Product Resource
  ProductResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref RestApi
      ParentId: !Ref ProductsResource
      PathPart: '{productId}'

  # Batch Operations Resource
  BatchResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref RestApi
      ParentId: !Ref ProductsResource
      PathPart: 'batch'

  # Lambda Function
  ProductApiFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub '${ProjectName}-${EnvironmentName}-product-api'
      Runtime: nodejs18.x
      Handler: product-api.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: !Ref ArtifactsBucket
        S3Key: 'lambda/product-api.zip'
      Environment:
        Variables:
          DYNAMODB_TABLE_NAME: !Ref MainTable
          ELASTICACHE_ENDPOINT: !If [IsProduction, !GetAtt ElastiCacheCluster.RedisEndpoint.Address, '']
          LOG_LEVEL: !If [IsProduction, 'INFO', 'DEBUG']
      Timeout: 30
      MemorySize: 512
      ReservedConcurrencyLimit: !If [IsProduction, 100, 10]
      DeadLetterQueue:
        TargetArn: !GetAtt DeadLetterQueue.Arn
      TracingConfig:
        Mode: Active

  # Lambda Permissions for API Gateway
  LambdaPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref ProductApiFunction
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub '${RestApi}/*/*'

  # API Methods - GET /products
  ListProductsMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref ProductsResource
      HttpMethod: GET
      AuthorizationType: NONE  # 本番では Cognito Authorizer を使用
      RequestValidatorId: !Ref RequestValidator
      RequestParameters:
        method.request.querystring.limit: false
        method.request.querystring.offset: false
        method.request.querystring.sort: false
        method.request.querystring.order: false
        method.request.querystring.category: false
        method.request.querystring.search: false
        method.request.querystring.status: false
        method.request.querystring.price_min: false
        method.request.querystring.price_max: false
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${ProductApiFunction.Arn}/invocations'
        CacheKeyParameters:
          - method.request.querystring.limit
          - method.request.querystring.offset
          - method.request.querystring.sort
          - method.request.querystring.order
          - method.request.querystring.category
        CachingEnabled: !If [IsProduction, true, false]
        CacheTtlInSeconds: !If [IsProduction, 300, 0]
      MethodResponses:
        - StatusCode: 200
          ResponseParameters:
            method.response.header.Access-Control-Allow-Origin: true
        - StatusCode: 400
        - StatusCode: 500

  # ElastiCache for Redis (Production only)
  ElastiCacheSubnetGroup:
    Type: AWS::ElastiCache::SubnetGroup
    Condition: IsProduction
    Properties:
      Description: 'Subnet group for ElastiCache'
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2

  ElastiCacheCluster:
    Type: AWS::ElastiCache::ReplicationGroup
    Condition: IsProduction
    Properties:
      ReplicationGroupDescription: 'Redis cluster for API caching'
      NumCacheClusters: 2
      Engine: redis
      CacheNodeType: cache.t3.micro
      SubnetGroupName: !Ref ElastiCacheSubnetGroup
      SecurityGroupIds:
        - !Ref ElastiCacheSecurityGroup
      AtRestEncryptionEnabled: true
      TransitEncryptionEnabled: true

  # CloudWatch Dashboard
  ApiDashboard:
    Type: AWS::CloudWatch::Dashboard
    Properties:
      DashboardName: !Sub '${ProjectName}-${EnvironmentName}-api-dashboard'
      DashboardBody: !Sub |
        {
          "widgets": [
            {
              "type": "metric",
              "properties": {
                "metrics": [
                  ["AWS/ApiGateway", "Count", "ApiName", "${RestApi}"],
                  [".", "Latency", ".", "."],
                  [".", "4XXError", ".", "."],
                  [".", "5XXError", ".", "."]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "${AWS::Region}",
                "title": "API Gateway Metrics"
              }
            },
            {
              "type": "metric",
              "properties": {
                "metrics": [
                  ["AWS/Lambda", "Invocations", "FunctionName", "${ProductApiFunction}"],
                  [".", "Duration", ".", "."],
                  [".", "Errors", ".", "."],
                  [".", "Throttles", ".", "."]
                ],
                "period": 300,
                "stat": "Average",
                "region": "${AWS::Region}",
                "title": "Lambda Function Metrics"
              }
            }
          ]
        }

Outputs:
  ApiEndpoint:
    Description: 'API Gateway endpoint URL'
    Value: !Sub 'https://${RestApi}.execute-api.${AWS::Region}.amazonaws.com/${EnvironmentName}'
    Export:
      Name: !Sub '${AWS::StackName}-ApiEndpoint'
  
  ProductApiFunctionArn:
    Description: 'Product API Lambda Function ARN'
    Value: !GetAtt ProductApiFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-ProductApiFunction'
```

## 検証方法

### 1. API機能テスト
```bash
# 商品作成
curl -X POST https://api.example.com/v1/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "description": "Test Description",
    "price": 99.99,
    "category": "electronics",
    "inventory": 100
  }'

# 商品一覧取得（フィルタ・ソート・ページネーション）
curl "https://api.example.com/v1/products?category=electronics&sort=price&order=asc&limit=10&offset=0"

# 商品更新
curl -X PUT https://api.example.com/v1/products/12345 \
  -H "Content-Type: application/json" \
  -d '{"price": 89.99}'
```

### 2. パフォーマンステスト
```bash
# 負荷テスト（Apache Bench）
ab -n 1000 -c 10 "https://api.example.com/v1/products"

# レスポンス時間測定
curl -w "@curl-format.txt" -o /dev/null -s "https://api.example.com/v1/products"
```

### 3. バリデーションテスト
```javascript
// 無効なデータでテスト
const invalidData = {
    name: "", // 空文字
    price: -10, // 負の値
    category: "invalid-category" // 無効なカテゴリ
};

// APIテスト
fetch('/products', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(invalidData)
});
```

## トラブルシューティング

### よくある問題と解決策

#### 1. 高レイテンシ
**症状**: API応答時間が遅い
**解決策**:
- DynamoDB の読み取り・書き込みキャパシティ確認
- Lambda関数のメモリ設定調整
- ElastiCache キャッシュヒット率確認

#### 2. スロットリング
**症状**: 429 Too Many Requests エラー
**解決策**:
```yaml
# API Gatewayスロットリング設定
MethodSettings:
  - ResourcePath: '/*'
    HttpMethod: '*'
    ThrottlingRateLimit: 1000
    ThrottlingBurstLimit: 2000
```

#### 3. バリデーションエラー
**症状**: 422 Validation Error の頻発
**解決策**:
- フロントエンドでの事前バリデーション実装
- エラーメッセージの改善
- API仕様書の詳細化

## 学習リソース

### 公式ドキュメント
- [API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)

### 追加学習教材
- [RESTful API Design](https://restfulapi.net/)
- [OpenAPI Specification](https://swagger.io/specification/)

## セキュリティとコストの考慮事項

### セキュリティベストプラクティス
1. **入力検証**: すべての入力データの厳密な検証
2. **レート制限**: API使用量の制御
3. **認証・認可**: JWT トークンベース認証
4. **HTTPS強制**: 全通信の暗号化

### コスト最適化
1. **キャッシュ活用**: ElastiCache・API Gatewayキャッシュ
2. **Lambda最適化**: 適切なメモリ・タイムアウト設定
3. **DynamoDB最適化**: 適切なキー設計・オンデマンド課金
4. **ログ管理**: CloudWatch Logs の適切な保持期間

### AWS Well-Architectedフレームワークとの関連
- **運用性の柱**: CloudWatch監視・X-Rayトレーシング
- **セキュリティの柱**: 認証・認可・入力検証・HTTPS
- **信頼性の柱**: エラーハンドリング・デッドレターキュー
- **パフォーマンス効率の柱**: キャッシュ・適切なデータ構造
- **コスト最適化の柱**: 従量課金・キャッシュ・適切なリソース設定

## 次のステップ

### 推奨される学習パス
1. **3.2.1 ファイルアップロード**: ファイル処理API実装
2. **3.2.2 リアルタイム更新**: WebSocket API実装
3. **4.1.1 Kinesisストリーミング**: イベント駆動処理
4. **5.2.1 チャットボット作成**: AI統合API

### 発展的な機能
1. **GraphQL API**: より柔軟なデータ取得
2. **API Versioning**: 下位互換性の維持
3. **Rate Limiting**: 高度な使用量制御
4. **API Analytics**: 詳細な使用状況分析

### 実践プロジェクトのアイデア
1. **Eコマース API**: 商品・注文・決済API
2. **ブログプラットフォーム**: コンテンツ管理API
3. **IoTデータ収集**: センサーデータ処理API
4. **ソーシャルメディア**: ユーザー・投稿・フォローAPI