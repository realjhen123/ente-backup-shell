#!/bin/sh

set -eu
service_name="my-ente"
pass="/var/lib/ente/backup/backup_pass.txt"
tar_verbose="-v"
gpg_verbose="-vvv"

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

tar $tar_verbose -cJf $output_postgres_tar_xz -C $(dirname -- $postgres_dir) $(basename -- $postgres_dir)
tar $tar_verbose -cf $output_minio_tar -C $(dirname -- $minio_dir) $(basename -- $minio_dir)

output_minio_gpg="$output_minio_tar.gpg"
output_postgres_gpg="$output_postgres_tar_xz.gpg"

echo "output_minio_gpg=$output_minio_gpg"
echo "output_postgres_gpg=$output_postgres_gpg"

echo "now gpg"
gpg $gpg_verbose --symmetric --cipher-algo AES256 -z 0 --batch --passphrase-file $pass -o $output_postgres_gpg $output_postgres_tar_xz
gpg $gpg_verbose --symmetric --cipher-algo AES256 -z 0 --batch --passphrase-file $pass -o $output_minio_gpg $output_minio_tar

echo "now test"

gpg $gpg_verbose --decrypt --pinentry-mode loopback --batch --passphrase-file $pass $output_minio_gpg > /dev/null
gpg $gpg_verbose --decrypt --pinentry-mode loopback --batch --passphrase-file $pass $output_postgres_gpg > /dev/null

echo "now tar docker"

tar $tar_verbose -cJf ${service_name}_docker.tar.xz -C $(dirname -- $ente_docker_dir) $(basename -- $ente_docker_dir)
gpg $gpg_verbose --symmetric --cipher-algo AES256 -z 0 --batch --passphrase-file $pass -o ${service_name}_docker.tar.xz.gpg ${service_name}_docker.tar.xz
gpg $gpg_verbose --decrypt --pinentry-mode loopback --batch --passphrase-file $pass ${service_name}_docker.tar.xz.gpg > /dev/null

echo "chmod to readonly"

chown root:root ${service_name}_docker.tar.xz $output_minio_gpg $output_postgres_gpg
chmod 744 ${service_name}_docker.tar.xz $output_minio_gpg $output_postgres_gpg

echo "remove tmp"

set +eu
rm $output_minio_tar
rm $output_postgres_tar_xz
rm ${service_name}_docker.tar.xz

echo "done"
