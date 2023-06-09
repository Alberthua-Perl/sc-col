#!/usr/bin/env python

'''
 1. Example custom dynamic inventory script for Ansible in Python.
 2. Modified by hualf on 2020-02-01.
 3. These hosts are included in HAproxy LAMP cluster.
'''

import os
import sys
import argparse

try:
    import json

except ImportError:
    import simplejson as json

class ExampleInventory(object):

    def __init__(self):
        self.inventory = {}
        self.read_cli_args()

        # Called with `--list`.
        if self.args.list:
            self.inventory = self.example_inventory()
        # Called with `--host [hostname]`.
        elif self.args.host:
            # Not implemented, since we return _meta info `--list`.
            self.inventory = self.empty_inventory()
        # If no groups or vars are present, return empty inventory.
        else:
            self.inventory = self.empty_inventory()

        print json.dumps(self.inventory);

    # Example inventory for testing.
    def example_inventory(self):
        return {
            'group': {
                'hosts': ['192.168.0.102', '192.168.0.109', '192.168.0.110', '192.168.0.108'],
                'vars': {
                    'ansible_ssh_user': 'webuser',
                    'ansible_ssh_pass': 'redhat',
                }
            },
            '_meta': {
                'hostvars': {
                    '192.168.0.102': {
                        'host_specific_var': 'foo'
                    },
                    '192.168.0.109': {
                        'host_specific_var': 'bar'
                    },
                    '192.168.0.110': {
                        'host_specific_var': 'red'
                    },
                    '192.168.0.108': {
                        'host_specific_var': 'hat'
                    }
                }
            }
        }

    # Empty inventory for testing.
    def empty_inventory(self):
        return {'_meta': {'hostvars': {}}}

    # Read the command line args passed to the script.
    def read_cli_args(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--list', action = 'store_true')
        parser.add_argument('--host', action = 'store')
        self.args = parser.parse_args()

# Get the inventory.
ExampleInventory()
