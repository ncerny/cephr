name 'cephr'
maintainer 'Nathan Cerny'
maintainer_email 'ncerny@gmail.com'
license 'apache2'
description 'Library Cookbook to Install and Manage Ceph Clusters'
long_description 'Library Cookbook to Install and Manage Ceph Clusters.'
version '0.3.0'

depends 'apt'
depends 'yum'
depends 'yum-epel'

source_url 'https://github.com/cerny-cc/cephr' if respond_to?(:source_url)
issues_url 'https://github.com/cerny-cc/cephr/issues' if respond_to?(:issues_url)
