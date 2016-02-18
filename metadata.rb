name 'cerny_ceph'
maintainer 'Nathan Cerny'
maintainer_email 'ncerny@gmail.com'
license 'apache2'
description 'Installs/Configures ceph'
long_description 'Installs/Configures ceph'
version '0.1.0'

conflicts 'ceph'

depends 'apt'
depends 'yum'
depends 'yum-epel'

source_url 'https://github.com/ncerny/cerny_ceph' if respond_to?(:source_url)
issues_url 'https://github.com/ncerny/cerny_ceph/issues' if respond_to?(:issues_url)
