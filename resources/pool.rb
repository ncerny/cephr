#
# Cookbook Name:: cerny_ceph
# Resource:: pool
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

resource_name 'ceph_pool'

property :name, String, name_property: true
property :pg_num, Integer, required: true
property :pgp_num, Integer
property :size, Integer
property :min_size, Integer
property :crush_ruleset, String

load_current_value do
  current_value_does_not_exist! unless exists?(name)
  pg_num Mixlib::ShellOut.new("ceph osd pool get #{name} pg_num").run_command.stdout.split[1].to_i
  pgp_num Mixlib::ShellOut.new("ceph osd pool get #{name} pgp_num").run_command.stdout.split[1].to_i
  size Mixlib::ShellOut.new("ceph osd pool get #{name} size").run_command.stdout.split[1].to_i
  min_size Mixlib::ShellOut.new("ceph osd pool get #{name} min_size").run_command.stdout.split[1].to_i
  crush_ruleset Mixlib::ShellOut.new("ceph osd pool get #{name} crush_ruleset").run_command.stdout.split[1]
end

action :create do
  fail 'Ceph Cluster is not available!' unless ceph_available?
  pgp_num = new_resource.pgp_num || ''
  crush_ruleset = new_resource.crush_ruleset || ''

  execute "Create Pool #{new_resource.name}" do
    command "ceph osd pool create #{new_resource.name} #{new_resource.pg_num} #{pgp_num} replicated #{crush_ruleset}"
    not_if "ceph osd pool stats #{new_resource.name}"
  end

  %w(pg_num pgp_num size min_size).each do |param|
    execute "ceph osd pool set #{new_resource.name} #{param} #{send(param)}" do
      not_if { current_resource && current_resource.send(param).eql?(send(param)) }
    end if send(param)
  end
end

action :delete do
  fail 'Ceph Cluster is not available!' unless ceph_available?
  execute "Delete Pool #{new_resource.name}" do
    command "ceph osd pool delete #{new_resource.name} #{new_resource.name} --yes-i-really-really-mean-it"
    only_if "ceph osd pool stats #{new_resource.name}"
  end
end

def exists?(pool)
  require 'timeout'
  begin
    Timeout.timeout(5) do
      Mixlib::ShellOut.new("ceph osd pool stats #{pool}").run_command.error!
      true
    end
  rescue
    false
  end
end
