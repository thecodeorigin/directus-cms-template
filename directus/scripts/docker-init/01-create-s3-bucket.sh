#!/bin/bash

echo "Initializing LocalStack S3 bucket for Directus..."

# Wait a moment for LocalStack to be fully ready
sleep 2

# Create the S3 bucket
awslocal s3 mb s3://directus-uploads

# Verify bucket was created
awslocal s3 ls

echo "LocalStack S3 bucket 'directus-uploads' created successfully!"
