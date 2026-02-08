#!/usr/bin/env python
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

# Written by pmartini2, but mostly a clone of fakebmc, written by jjohnson2
__author__ = 'pmartini2@bloomberg.net'

# This is a simple, but working proof of concept of using pyghmi.ipmi.bmc to
# control a VM

import argparse
import libvirt
import pyghmi.ipmi.bmc as bmc
import pyghmi.ipmi.command as ipmicommand
import sys
import lxml.etree as etree


class LibvirtBmc(bmc.Bmc):
    """A class to provide an IPMI interface to the VirtualBox APIs."""

    def __init__(self, authdata, hypervisor, domain, address, port):
        super(LibvirtBmc, self).__init__(authdata, address, port)
        # Rely on libvirt to throw on bad data
        self.name = domain
        self._vm_name = domain
        self.hypervisor = hypervisor
        self.domain = domain
#        try:
#            conn = libvirt.open(hypervisor)
#        except Exception, e:
#            sys.stderr.write('Failed to connect to %s\n' % self.hypervisor)
#            sys.exit(131)
#        try:
#            domain = self.conn.lookupByName(self.domain)
#        except Exception, e:
#            sys.stderr.write('Could not connect to %s\n' % domain)
#            sys.exit(132)

    # Disable default BMC server implementations

    def _get_conn_domain(self):
        try:
            conn = libvirt.open(self.hypervisor)
        except Exception, e:
            sys.stderr.write('Failed to connect to %s\n' % self.hypervisor)
            return (None, None)
        try:
            domain = conn.lookupByName(self.domain)
        except Exception, e:
            sys.stderr.write('Could not connect to %s\n' % domain)
            return (None, None)
        return (conn, domain)


    def cold_reset(self):
        """Cold reset reset the BMC so it's not implemented."""
        raise NotImplementedError

    def get_boot_device(self):
        conn, domain = self._get_conn_domain()
        if domain is None:
          return None
    xmldesc = etree.fromstring(domain.XMLDesc())
    bootdev = xmldesc.xpath('//domain/os/boot')[0].get('dev')
    if bootdev in ipmicommand.boot_devices.keys():
        return ipmicommand.boot_devices[bootdev]
    else:
        return None

    def get_system_boot_options(self, request, session):
        sys.stderr.write("%s: get boot options\n" % self.name)
        if request['data'][0] == 5:  # boot flags
            try:
                bootdevice = self.get_boot_device()
            except NotImplementedError:
                session.send_ipmi_response(data=[1, 5, 0, 0, 0, 0, 0])
            if (type(bootdevice) != int and
                    bootdevice in ipmicommand.boot_devices):
                bootdevice = ipmicommand.boot_devices[bootdevice]
            paramdata = [1, 5, 0b10000000, bootdevice, 0, 0, 0]
            return session.send_ipmi_response(data=paramdata)
        else:
            session.send_ipmi_response(code=0x80)



    def set_boot_device(self, bootdevice):
        bootmap = {
          'net': 'network',
          'pxe': 'network',
          'network': 'network',
          1: 'network',
          'hd': 'hd',
          'cd': 'cdrom',
          'cdrom': 'cdrom',
          'optical': 'cdrom',
          'floppy': 'fd',
          'fd': 'fd'
        }
        sys.stderr.write('Setting bootdevice for %s to %s\n' % (self.name, bootdevice))
        conn, domain = self._get_conn_domain()
        if domain is None:
          return None
        if bootdevice in bootmap.keys():
            newboot = bootmap[bootdevice]
            if newboot == 'hd':
                backupboot = 'network'
            if newboot == 'network':
                backupboot = 'hd'
        else:
            sys.stderr.write('Unsupported bootdevice: %s\n' % bootdevice)
            return None

        try:
            xmldesc = etree.fromstring(domain.XMLDesc())
            xmldesc.xpath('//domain/os/boot')[0].set('dev', newboot)
            try:
                xmldesc.xpath('//domain/os/boot')[1].set('dev', backupboot)
            except:
                pass
            if conn.defineXML(etree.tostring(xmldesc)):
                sys.stderr.write('Success\n')
                return True
            else:
                sys.stderr.write('Failure\n')
                return False
        except Exception as e:
            sys.stderr.write('Error modifying boot device for %s\n' % self.name)
            sys.stderr.write(str(e))
            return 0xce

    def set_kg(self, kg):
        """Desactivated IPMI call."""
        raise NotImplementedError


    def set_system_boot_options(self, request, session):
        #logging.info("set boot options vm:" + self._vm_name)
        if request['data'][0] in (0, 3, 4):
            #logging.info("Ignored RAW option " + str(request['data']) + " for: " + self._vm_name + "... Smile and wave.")
            # for now, just smile and nod at boot flag bit clearing
            # implementing it is a burden and implementing it does more to
            # confuse users than serve a useful purpose
            session.send_ipmi_response(code=0x00)
        elif request['data'][0] == 5:
            bootdevice = (request['data'][2] >> 2) & 0b1111
            #logging.info("Got set boot device for " + self._vm_name + " to " + str(request['data'][2]))
            sys.stderr.write("Got set boot device for " + self.name + " to " + str(request['data'][2]) + '\n')
            try:
                bootdevice = ipmicommand.boot_devices[bootdevice]
                sys.stderr.write("Setting boot device for " + self.name + " to " + bootdevice + '\n')
            except KeyError:
                session.send_ipmi_response(code=0xcc)
                return
            self.set_boot_device(bootdevice)
            session.send_ipmi_response()
        else:
            raise NotImplementedError


    def get_power_state(self):
        conn, domain = self._get_conn_domain()
        if domain is None:
          return None
  
        if domain.isActive():
            return 'on'
        else:
            return 'off'

    def power_off(self):
        conn, domain = self._get_conn_domain()
        if domain is None:
          return None
        if not domain.isActive():
            return 0xd5  # Not valid in this state
        domain.destroy()

    def power_on(self):
        conn, domain = self._get_conn_domain()
        if domain is None:
          return None
        if domain.isActive():
            return 0xd5  # Not valid in this state
        domain.create()

    def power_reset(self):
        conn, domain = self._get_conn_domain()
        if domain is None:
          return None
        if not domain.isActive():
            return 0xd5  # Not valid in this state
        domain.reset()

    def power_shutdown(self):
        conn, domain = self._get_conn_domain()
        if domain is None:
          return None
        if not domain.isActive():
            return 0xd5  # Not valid in this state
        domain.shutdown()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='virshbmc',
        description='Pretend to be a BMC and proxy to virsh',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('--port',
                        dest='port',
                        type=int,
                        default=623,
                        help='(UDP) port to listen on')
    parser.add_argument('--address',
                        dest='address',
                        default='localhost',
                        help='The address to listen on')
    parser.add_argument('--connect',
                        dest='hypervisor',
                        default='qemu:///system',
                        help='The hypervisor to connect to')
    parser.add_argument('--domain',
                        dest='domain',
                        required=True,
                        help='The name of the domain to manage')
    args = parser.parse_args()
    mybmc = LibvirtBmc({'admin': 'password'},
                       hypervisor=args.hypervisor,
                       domain=args.domain,
                       address=args.address,
                       port=args.port)
    mybmc.listen()
