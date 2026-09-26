#!/bin/sh

set -eu
service_name="my-ente"
pass="/var/lib/ente/backup/backup_pass.txt"

today=$(date +%Y%m%d)

minio_dir="/var/lib/docker/volumes/${service_name}_minio-data"
postgres_dir="/var/lib/docker/volumes/${service_name}_postgres-data"
ente_docker_dir="/var/lib/ente/${service_name}/"

echo "minio_dir=$minio_dir"
echo "postgres_dir=$postgres_dir"
echo "ente_docker_dir=$ente_docker_dir"

output_minio_tar="$(basename -- $minio_dir)-$today.tar"
output_postgres_tar_xz="$(basename -- $postgres_dir)-$today.tar.xz"

echo "output_minio_tar=$output_minio_tar"
echo "output_postgres_tar_xz=$output_postgres_tar_xz"

tar -cvJf $output_postgres_tar_xz $postgres_dir
tar -cvf $output_minio_tar $minio_dir

output_minio_gpg="$output_minio_tar.gpg"
output_postgres_gpg="$output_postgres_tar_xz.gpg"

echo "output_minio_gpg=$output_minio_gpg"
echo "output_postgres_gpg=$output_postgres_gpg"

echo "now gpg"
gpg --symmetric --cipher-algo AES256 -z 0 --batch --passphrase-file $pass -o $output_postgres_gpg $output_postgres_tar_xz
gpg --symmetric --cipher-algo AES256 -z 0 --batch --passphrase-file $pass -o $output_minio_gpg $output_minio_tar

echo "now test"

gpg --decrypt --pinentry-mode loopback --batch --passphrase-file $pass $output_minio_gpg > /dev/null
gpg --decrypt --pinentry-mode loopback --batch --passphrase-file $pass $output_postgres_gpg > /dev/null

echo "now tar docker"

tar -cvJf $ente_docker_dir ${service_name}_docker.tar.xz

echo "chmod to readonly"

chown root:root ${service_name}_docker.tar.xz $output_minio_gpg $output_postgres_gpg
chmod 744 ${service_name}_docker.tar.xz $output_minio_gpg $output_postgres_gpg

echo "remove tmp"

rm $output_minio_tar
rm $output_postgres_tar_xz

echo "done"
