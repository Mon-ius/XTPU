from google.cloud import storage

client = storage.Client()
bucket_name = 'pytorch-xla-releases'
directory_name = 'wheels/cuda'

blobs = client.list_blobs(bucket_name, prefix=directory_name)

for blob in blobs:
    print(blob.name)