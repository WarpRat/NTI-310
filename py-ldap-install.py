#!/usr/bin/env python
#
#Python script that installs ldap server and stores the
#server IP in gloud metadata server
#

import googleapiclient.discovery
import os
import time
import re

project = 'nti310-320'
zone = 'us-west1-a'
size = 'f1-micro'
script_name = 'ldap-install.sh'

compute = googleapiclient.discovery.build('compute', 'v1')

def create_instance(compute, name, startup_script, project, zone, size):
  '''Creates gcloud instance using project, script, zone, size, and name vars'''
  
  image_response = compute.images().getFromFamily(
      project='centos-cloud', family='centos-7').execute()
  source_disk_image = image_response['selfLink']

  machine_type = 'zones/%s/machineTypes/%s' % (zone, size)


  config = {
  	'name': name,
  	'machineType': machine_type,

  	'disks': [
  	  {
  	  	'boot': True,
  	  	'autoDelete': True,
 	  	'initializeParams': {
  	  		'sourceImage': source_disk_image,
  	  		'diskSizeGb': '10',
  	  	}
  	  }
  	],

  	'networkInterfaces': [{
  		'network': 'global/networks/default',
  		'accessConfigs': [
  		  {'type': 'ONE_TO_ONE_NAT', 'name': 'External NAT', 'networkTier': 'PREMIUM'}
  		  ]
  		}],

    'description': '',
    'labels': {},
    'scheduling': {
      'preemptible': False,
      'onHostMaintenance': 'MIGRATE',
      'automaticRestart': True
    },
   'tags': {
    'items': [
      'http-server',
      'https-server'
     ]
    },
    'deletionProtection': False,
    'serviceAccounts': [
      {
        'email': 'default',
        'scopes': [
          'https://www.googleapis.com/auth/devstorage.read_only',
          'https://www.googleapis.com/auth/logging.write',
          'https://www.googleapis.com/auth/monitoring.write',
          'https://www.googleapis.com/auth/servicecontrol',
          'https://www.googleapis.com/auth/service.management.readonly',
          'https://www.googleapis.com/auth/compute',
          'https://www.googleapis.com/auth/trace.append']
          }
        ],
    'metadata': {
  	  'items': [{
  		  'key': 'startup-script',
  		  'value': startup_script
       },
       {
          'key': 'serial-port-enable',
          'value': '1'
       }]
    }
  }

  return compute.instances().insert(
    project=project,
    zone=zone,
    body=config).execute()

#Function to check the status of specific gcloud api calls. Directly copied from source below:
# [START wait_for_operation] - from https://github.com/GoogleCloudPlatform/python-docs-samples/blob/master/compute/api/create_instance.py
def wait_for_operation(compute, project, zone, operation):
    '''Check if an api call to gcloud is finished and show errors'''

    print('Waiting for operation to finish...')
    while True:
        result = compute.zoneOperations().get(
            project=project,
            zone=zone,
            operation=operation).execute()

        if result['status'] == 'DONE':
            print('done.')
            if 'error' in result:
                raise Exception(result['error'])
            return result

        time.sleep(1)
# [END wait_for_operation]

def wait_for_install(id):
  '''Continually check meta-data server to see if the finished key is writted'''
  while True:
    result = compute.instances().list(project=project, zone=zone, filter=id).execute()
    keys = []
    for i in result['items'][0]['metadata']['items']:
      keys.append(i['key'])
    if 'finished' in keys:
      print('finished')
      break
    else:
      print('not ready yet')
      time.sleep(10)

#Handle instance name collision errors
def build(name, startup_script):
  '''Small wrapper around creating instances to handle name collisions gracefully'''

  operation = ''

  try:
    operation = create_instance(compute, name, startup_script, project, zone, size)

    wait_for_operation(compute, project, zone, operation['name'])


  except Exception as e:
    print('ERROR')
    print(e)
    if name in str(e) and 'already exists' in str(e):
      if re.search(r'-[0-9]', name[-2:]):
        name = name[:-1] + str(int(name[-1:]) + 1)
        return build(name, startup_script)

      else:
        name = name + '-1'
        return build(name, startup_script)

  else:
     return operation['targetId']

#Ingest bash script for setting up ldap server
def ldap(script_name):
  '''Pull in script to install ldap'''
  startup_script = open(
  os.path.join(
    os.path.dirname(__file__), script_name), 'r').read()

  ldap_id = build('ldap-server', startup_script)

  filter_id = 'id=' + ldap_id
  result = compute.instances().list(project=project, zone=zone, filter=filter_id).execute()

  wait_for_install(filter_id)

  ip = result['items'][0]['networkInterfaces'][0]['networkIP']

  return ip

def write_metadata(key_name, value):
  '''write a new key value pair to project wide metadata'''

  request = compute.projects().get(project=project).execute()
  cur_meta = request['commonInstanceMetadata']['items']
  fingerprint = request['commonInstanceMetadata']['fingerprint']
  new_meta = cur_meta.append({'key': key_name, 'value': value})
  body = {'fingerprint': fingerprint, 'items': new_meta}

  result = compute.projects().setCommonInstanceMetadata(project=project, body=body).execute

  wait_for_operation(compute, project, zone, result['name'])

if __name__ == '__main__':

  ldap_ip=ldap(script_name)
  write_metadata('ldap_ip',ldap_ip)
