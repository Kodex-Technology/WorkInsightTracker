import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

let s3ClientInstance = null;

export function getS3Client() {
  if (!s3ClientInstance) {
    const region = process.env.AWS_REGION || 'us-east-1';
    const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
    const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;

    const config = { region };
    if (accessKeyId && secretAccessKey) {
      config.credentials = { accessKeyId, secretAccessKey };
    }
    s3ClientInstance = new S3Client(config);
  }
  return s3ClientInstance;
}

export async function generateScreenshotPresignedUrl({ backendUserId, captureDate, screenshotId, expiresIn = 300, contentType = 'application/octet-stream' }) {
  const bucket = process.env.AWS_S3_BUCKET;
  if (!bucket) {
    throw new Error('AWS_S3_BUCKET environment variable is not configured');
  }
  if (!backendUserId || !captureDate || !screenshotId) {
    throw new Error('Missing required parameters for S3 object key generation');
  }

  const extension = contentType === 'image/png' ? 'png' : 'bin';
  const objectKey = `users/${backendUserId}/${captureDate}/${screenshotId}.${extension}`;
  const client = getS3Client();

  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: objectKey,
    ContentType: contentType,
    ServerSideEncryption: 'AES256',
  });

  const uploadUrl = await getSignedUrl(client, command, { expiresIn });

  return {
    objectKey,
    uploadUrl,
    expiresIn,
    requiredHeaders: {
      'Content-Type': contentType,
      'x-amz-server-side-encryption': 'AES256',
    },
  };
}

export async function generateScreenshotDownloadUrl({ objectKey, expiresIn = 600 }) {
  const bucket = process.env.AWS_S3_BUCKET;
  if (!bucket) throw new Error('AWS_S3_BUCKET environment variable is not configured');
  if (!objectKey || typeof objectKey !== 'string' || objectKey.includes('..')) {
    throw new Error('Invalid S3 object key');
  }
  return getSignedUrl(
    getS3Client(),
    new GetObjectCommand({ Bucket: bucket, Key: objectKey }),
    { expiresIn },
  );
}
