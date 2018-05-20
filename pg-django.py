#!/usr/bin/env python
#
#A python script for launching a postgres database and a django webserver that uses
#the postgres database as a backend.
#Google Cloud Api python library code borrowed heavily from:
#https://github.com/GoogleCloudPlatform/python-docs-samples/blob/master/compute/api/create_instance.py
#
#This script relies on either running from a gcloud instance/cloud shell or having gcloud authentication already
#configured on the machine it's run from. It doesn't handle any authorization
#


import googleapiclient.discovery
import os
import time
from pprint import pprint
import re

project = 'nti310-320'
zone = 'us-west1-a'
name = 'test-instance-100'
compute = googleapiclient.discovery.build('compute', 'v1')


def create_instance(compute, name, startup_script, project, zone):
  image_response = compute.images().getFromFamily(
    project='centos-cloud', family='centos-7').execute()
  source_disk_image = image_response['selfLink']
  
  machine_type = 'zones/%s/machineTypes/f1-micro' % zone

  
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
          'https://www.googleapis.com/auth/trace.append']
          }
        ],
    'metadata': {
  	  'items': [{
  		  'key': 'startup-script',
  		  'value': startup_script
       }]
    }
  }
  
  return compute.instances().insert(
    project=project,
    zone=zone,
    body=config).execute()

# [START wait_for_operation] - from https://github.com/GoogleCloudPlatform/python-docs-samples/blob/master/compute/api/create_instance.py
def wait_for_operation(compute, project, zone, operation):
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



def build(name, startup_script):  
  
  operation = ''
  result = ''
  
  try:
    operation = create_instance(compute, name, startup_script, project, zone)
    #pprint(operation)
    wait_for_operation(compute, project, zone, operation['name'])
    
    
  except Exception as e:
    print('ERRROR')
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

def postgres():
    
    startup_script = open(
    os.path.join(
      os.path.dirname(__file__), 'pgsql-install.sh'), 'r').read()
    startup_script_edit = re.sub(r'(?<=postgres WITH PASSWORD ).*;', '\'{postgres}\';', startup_script)
    startup_script_edit = re.sub(r'(?<=db_srv WITH PASSWORD ).*;', '{db_srv};', startup_script_edit)
    
    startup_script = startup_script_edit.format(postgres='test123', db_srv='test321')
    
    db_id = build('postgres', startup_script)
    filter_id = 'id=' + db_id
    result = compute.instances().list(project=project, zone=zone, filter=filter_id).execute()
    return result['items'][0]['networkInterfaces'][0]['accessConfigs'][0]['natIP']

    
if __name__ == '__main__':
  
  
  #build(name, 'nfs-server.sh')