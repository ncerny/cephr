#
# Cookbook Name:: cephr
# Resource:: mon
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

resource_name 'ceph_mgr'

property :name, String, name_property: true
property :keyring, String

load_current_value do

end

action :create do
  directory "/var/lib/ceph/mgr/#{node.run_state['cephr']['cluster']}-#{new_resource.name}" do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
    action :create
  end

  package 'ceph-mgr' do
    only_if 'yum search -C ceph-mgr | grep ceph-mgr'
  end

  package 'ceph' do
    not_if 'yum search -C ceph-mgr | grep ceph-mgr'
  end

  ceph_auth 'client.admin' do
    caps mon: 'allow *',
         osd: 'allow *',
         mds: 'allow *',
         mgr: 'allow *'
    not_if 'ceph auth get client.admin | grep "caps mgr"'
  end

  ceph_auth "mgr.#{new_resource.name}" do
    caps mon: 'allow profile mgr',
         osd: 'allow *',
         mds: 'allow *'
    output "/var/lib/ceph/mgr/#{node.run_state['cephr']['cluster']}-#{new_resource.name}/keyring"
    not_if { ::File.exist?("/var/lib/ceph/mgr/#{node.run_state['cephr']['cluster']}-#{new_resource.name}/keyring") }
  end

  service 'ceph.target' do
    supports restart: true, status: true
    action [:enable, :start]
  end if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)

  service 'ceph-mgr' do
    if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)
      service_name "ceph-mgr@#{new_resource.name}.service"
    elsif Chef::Platform::ServiceHelpers.service_resource_providers.include?(:upstart)
      service_name 'ceph-mgr'
      parameters id: new_resource.name
    end
    supports restart: true, status: true
    action [:enable, :start]
  end
end
