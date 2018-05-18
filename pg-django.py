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

def create_instance(compute, name, startup_script_file, project='nti310-320', zone='us-west1-a'):
  image_response = compute.images().getFromFamily(
    project='centos-cloud', family='centos-7').execute()
  source_disk_image = image_response['selfLink']
  
  machine_type = 'zones/%s/machineTypes/f1-micro' % zone
  startup_script = open(
    os.path.join(
      os.path.dirname(__file__), startup_script_file), 'r').read()
  
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

if __name__ == '__main__':
  compute = googleapiclient.discovery.build('compute', 'v1')
  create_instance(compute, 'test-instance-120', 'nfs-server.sh' )
