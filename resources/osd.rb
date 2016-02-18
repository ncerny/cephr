#
# Cookbook Name:: cerny_ceph
# Resource:: osd
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
# rubocop:disable LineLength

require_relative '../libraries/helpers'
include CernyCeph::Helpers

resource_name 'ceph_osd'

property :name, String, name_property: true
property :fqdn, String, required: true
property :dev, String
property :journal, String
property :fs_type, String, default: 'xfs'
property :uuid, String
property :id, Integer

load_current_value do
  current_value_does_not_exist! unless exists?(name.split('.')[1])
end

action :create do
  return unless new_resource.fqdn == node['fqdn']
  new_resource.uuid ||= SecureRandom.uuid
  new_resource.id ||= new_resource.name.split('.')[1].to_i

  execute "ceph osd create #{new_resource.uuid} #{new_resource.id}" do
    not_if { current_resource }
  end

  directory "/var/lib/ceph/osd/#{node.run_state['ceph']['cluster']}-#{new_resource.id}" do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
  end

  if new_resource.dev
    new_resource.dev = '/dev/' + new_resource.dev unless new_resource.dev.start_with?('/')
    execute "mkfs -t #{new_resource.fs_type} #{new_resource.dev}" do
      not_if { current_resource }
    end

    execute "mount -o noatime #{dev} /var/lib/ceph/osd/#{node.run_state['ceph']['cluster']}-#{new_resource.id}" do
      not_if { current_resource }
      notifies :create, "directory[/var/lib/ceph/osd/#{node.run_state['ceph']['cluster']}-#{new_resource.id}]", :immediately
    end
  end

  execute "ceph-osd -i #{new_resource.id} --mkfs --mkkey --osd-uuid #{new_resource.uuid}" do
    user 'ceph'
    not_if { current_resource }
  end

  execute "ceph auth add #{new_resource.name} osd 'allow *' mon 'allow profile osd' -i /var/lib/ceph/osd/#{node.run_state['ceph']['cluster']}-#{new_resource.id}/keyring" do
    not_if { current_resource }
  end

  # execute "ceph osd crush add-bucket #{node['fqdn']} host" do
  #   not_if { current_resource }
  # end
  #
  # execute "ceph osd crush move #{node['fqdn']} root=default" do
  #   not_if { current_resource }
  # end
  #
  # execute "ceph osd crush add #{new_resource.name} 1.0 host=#{node['fqdn']}" do
  #   not_if { current_resource }
  # end

  file "/var/lib/ceph/osd/#{node.run_state['ceph']['cluster']}-#{new_resource.id}/done" do
    user 'ceph'
    action :touch
  end

  service 'ceph.target' do
    supports restart: true, status: true
    action [:enable, :start]
  end if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)

  service "ceph-osd-#{new_resource.id}" do
    if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)
      service_name "ceph-osd@#{new_resource.id}.service"
    elsif Chef::Platform::ServiceHelpers.service_resource_providers.include?(:upstart)
      service_name 'ceph-osd'
      parameters id: new_resource.id
    end
    supports restart: true, status: true
    action [:enable, :start]
  end
end

action :start do

end

action :stop do

end

action :restart do

end

action :configure do

end

action :remove do

end

def exists?(osd)
  Mixlib::ShellOut.new("ceph osd find #{osd}").run_command.error!
  true
rescue
  false
end
