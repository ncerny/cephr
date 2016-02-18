# #
# # Cookbook Name:: cerny_ceph
# # Resource:: auth
# #
# # Copyright 2016 Nathan Cerny
# #
# # Licensed under the Apache License, Version 2.0 (the "License");
# # you may not use this file except in compliance with the License.
# # You may obtain a copy of the License at
# #
# #     http://www.apache.org/licenses/LICENSE-2.0
# #
# # Unless required by applicable law or agreed to in writing, software
# # distributed under the License is distributed on an "AS IS" BASIS,
# # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# # See the License for the specific language governing permissions and
# # limitations under the License.
# # rubocop:disable LineLength
#
# require_relative '../libraries/helpers'
# include CernyCeph::Helpers
#
# resource_name 'ceph_auth'
#
# property :entity, String, name_property: true
# property :caps, [String, Hash], required: true
# attr_reader :key
#
# load_current_value do
#   cmd = Mixlib::ShellOut.new("ceph auth get #{entity}").run_command
#   current_value_does_not_exist! if cmd.error!
#   parse(cmd.stdout)
#   caps node.run_state['ceph']['auth'][entity]['caps']
#   key node.run_state['ceph']['auth'][entity]['key']
# end
#
# action :add do
#   execute "ceph auth add #{new_resource.entity} #{print_caps(new_resource.caps)}" do
#     not_if { current_resource }
#   end
# end
#
# action :delete do
#   execute "ceph auth del #{new_resource.entity}" do
#     only_if { current_resource }
#   end
# end
#
# # def parse(a)
# #   a.lines.each do |line|
# #
# #     line.split(' = ') do |k, v|
# #       case k
# #       when 'key'
# #         node.run_state['ceph']['auth'][new_resource.entity]
# #   end
# # end
#
# def print_caps(c)
#   str = ''
#   parse_caps(c).each { |k, v| str += "#{k} '#{v}' " }
#   str.strip
# end
