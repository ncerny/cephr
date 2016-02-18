#
# Cookbook Name:: test
# Recipe:: default
#
# Copyright 2016 Nathan Cerny
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ceph_cluster 'ceph' do
  version node['ceph']['version']
  monitors 'default-bento-centos-72' => '192.168.247.21',
           'default-bento-debian-82' => '192.168.247.22',
           'default-bento-ubuntu-1404' => '192.168.247.23'
  fsid '58c706a2-b021-4591-b318-91c9d3882685'
  config <<-EOF
  [global]
    public network = 192.168.247.0/24
    auth client required = cephx
    auth cluster required = cephx
    auth service required = cephx
    filestore xattr use omap = true
    osd journal size = 5120
    osd pool default min size = 1
    osd pool default size = 2
    max open files = 131072

  [osd]
    keyring = /var/lib/ceph/osd/ceph-$id/keyring
    filestore min sync interval = 10
    filestore max sync interval = 30
    filestore queue max ops = 25000
    filestore queue max bytes = 10485760
    filestore queue committing max ops = 5000
    filestore queue committing max bytes = 10485760000
    filestore op threads = 32

  [mds]
    mds cache size = 250000

  EOF
end

ceph_mon node['hostname'] do
  monitor_secret 'AQCS2rJWs1ZlDxAACh7GZoxYXp86fJ8aAplvWA=='
  admin_secret 'AQCS2rJWl6yHDRAAXX3gQGZrDKmGtU1Tdq4Fvg=='
  osd_bootstrap_secret 'AQA31hVWrke4GhAAHfKU4POaKpaqvuhDSnwlLA=='
end

ceph_osd 'osd.0' do
  host 'default-bento-centos-72'
end

ceph_osd 'osd.1' do
  host 'default-bento-debian-82'
end

ceph_osd 'osd.2' do
  host 'default-bento-ubuntu-1404'
end

# Example of using a disk instead of a directory
# ceph_osd 'osd.4' do
#   host 'default-bento-centos-72'
#   dev '/dev/sdb'
#   fs_type 'xfs'
# end

ceph_pool 'rbd' do
  pg_num 64
  size 2
  min_size 1
end

ceph_pool 'data' do
  pg_num 128
  size 2
  min_size 1
end

ceph_pool 'metadata' do
  pg_num 128
  size 2
  min_size 1
end
