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

### Cluster Configuration and Package Installation ###
ceph_cluster 'cephr' do
  version node['cephr']['version']
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

### Create the Keyrings needed for authentication ###
# Write the Admin keyring that we need to authenticate to the Ceph Cluster
ceph_keyring 'client.admin' do
  secret 'AQCS2rJWl6yHDRAAXX3gQGZrDKmGtU1Tdq4Fvg=='
  keyring '/etc/ceph/ceph.client.admin.keyring'
  uid 0
  caps mon: 'allow *',
       osd: 'allow *',
       mds: 'allow *'
  sensitive true
end

# Write out the bootstrap-osd keyring so the osd can join the Ceph cluster.
ceph_keyring 'client.bootstrap-osd' do
  secret 'AQA31hVWrke4GhAAHfKU4POaKpaqvuhDSnwlLA=='
  keyring '/var/lib/ceph/bootstrap-osd/ceph.keyring'
  caps mon: 'allow profile bootstrap-osd'
  sensitive true
end

# Write out the bootstrap-mds keyring so the mds can join the Ceph cluster.
ceph_keyring 'client.bootstrap-mds' do
  secret 'AQBlXctWxAZ4IBAALA6KgrJgi3OT9nkBHEDmJg=='
  keyring '/var/lib/ceph/bootstrap-mds/ceph.keyring'
  caps mon: 'allow profile bootstrap-mds'
  sensitive true
end

# Write out the bootstrap-rgw keyring so the rgw can join the Ceph cluster.
ceph_keyring 'client.bootstrap-rgw' do
  secret 'AQBlXctWUrSAFxAAy0TyyzdplGsAHuC8PRQs7g=='
  keyring '/var/lib/ceph/bootstrap-rgw/ceph.keyring'
  caps mon: 'allow profile bootstrap-rgw'
  sensitive true
end

# Write the Monitor keyring, and import the other keyrings into it.
ceph_keyring 'mon.' do
  secret 'AQCS2rJWs1ZlDxAACh7GZoxYXp86fJ8aAplvWA=='
  keyring '/var/lib/ceph/tmp/ceph.mon.keyring'
  import [
    '/etc/ceph/ceph.client.admin.keyring',
    '/var/lib/ceph/bootstrap-osd/ceph.keyring',
    '/var/lib/ceph/bootstrap-mds/ceph.keyring',
    '/var/lib/ceph/bootstrap-rgw/ceph.keyring'
  ]
  caps mon: 'allow *'
  action [:write, :import]
  sensitive true
end

### Create the Monitors ###
ceph_mon node['fqdn']

# Early return if the cluster isn't fully up yet.
# We do this so that kitchen converge doesn't die before creating all nodes.
require 'timeout'
begin
  Timeout.timeout(5) do
    cmd = Mixlib::ShellOut.new('ceph mon_status').run_command
    cmd.error!
  end
rescue
  return
end

## Add and Configure the Pools ###
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

### Create the OSDs ###
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

### Create the Metadata Servers ###
ceph_mds node['fqdn']

### Create the cephfs ###
ceph_fs 'cephfs'

directory '/mnt/cephfs'

# ceph_fs '/mnt/cephfs' do
#
#   property :mount_point, String, name_property: true
#   property :name, String, default: 'cephfs'
#   property :data_pool, String, default: 'data'
#   property :metadata_pool, String, default: 'metadata'
#   property :mount_point, String, default: '/mnt/cephfs'
#   property :client, String, default: 'admin'
#   property :fuse, [TrueClass, FalseClass], default: false
#   property :key, String
#   property :keyring
#
# end
