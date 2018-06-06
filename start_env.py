#!/usr/bin/env python

import googleapiclient.discovery  #The python gcloud API wrapper
import os  #For various file manipulation
import time  #To wait.
from pprint import pprint  #Useful for debugging - can be removed when finished
import re  #Regex engine for editing startup scripts before passing to gcloud
import random  #To generate passwords
import string  #To quickly build character lists for password generation


#Global Variables

project = 'nti310-320'
zone = 'us-west1-a'
pw_dir = '.script_passwd'

compute = googleapiclient.discovery.build('compute', 'v1')

centos7_img = {'project': 'centos-cloud', 'family': 'centos-7'}
ubuntu_xenial_img = {'project': 'ubuntu-os-cloud', 'family': 'ubuntu-1604-lts'}


def create_instance(compute, name, startup_script, project, zone, image):
  '''Creates gcloud instance using project, script, zone, and name vars'''
  
  image_response = compute.images().getFromFamily(
      project=image['project'], family=image['family']).execute()
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

#Handle instance name collision errors
def build(name, startup_script, image):
  '''Small wrapper around creating instances to handle name collisions gracefully'''

  operation = ''

  try:
    operation = create_instance(compute, name, startup_script, project, zone, image)

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
def ldap_server(script_name, name):
  '''Pull in script to install ldap'''
  startup_script = open(
  os.path.join(
    os.path.dirname(__file__), script_name), 'r').read()

  ldap_id = build(name, startup_script, centos7_img)

  filter_id = 'id=' + ldap_id
  result = compute.instances().list(project=project, zone=zone, filter=filter_id).execute()

  ip = result['items'][0]['networkInterfaces'][0]['networkIP']

  return {'ip': ip, 'id': ldap_id}

#Ingest bash script for setting up ldap server
def ldap_client(script_name, name):
  '''Pull in script to install ldap'''
  startup_script = open(
  os.path.join(
    os.path.dirname(__file__), script_name), 'r').read()

  ldap_id = build(name, startup_script, ubuntu_xenial_img)

  filter_id = 'id=' + ldap_id
  result = compute.instances().list(project=project, zone=zone, filter=filter_id).execute()

  ip = result['items'][0]['networkInterfaces'][0]['networkIP']

  return {'ip': ip, 'id': ldap_id}

#Ingest bash script for setting up NFS server
def nfs_server(script_name, name):
  '''Pull in script to install ldap'''
  startup_script = open(
  os.path.join(
    os.path.dirname(__file__), script_name), 'r').read()

  nfs_id = build(name, startup_script, centos7_img)

  filter_id = 'id=' + nfs_id
  result = compute.instances().list(project=project, zone=zone, filter=filter_id).execute()

  ip = result['items'][0]['networkInterfaces'][0]['networkIP']

  return {'ip': ip, 'id': nfs_id}

def nfs_client(script_name, name):
  '''Pull in script to install ldap'''
  startup_script = open(
  os.path.join(
    os.path.dirname(__file__), script_name), 'r').read()

  nfs_client_id = build(name, startup_script, ubuntu_xenial_img)

  filter_id = 'id=' + nfs_client_id
  result = compute.instances().list(project=project, zone=zone, filter=filter_id).execute()
  
  ip = result['items'][0]['networkInterfaces'][0]['networkIP']

  return {'ip': ip, 'id': nfs_client_id}

#Ingest bash script for setting up postgresql making changes where nessecary
def postgres(startup_script, name):
    '''Pull in a script named pgsql-install.sh and install with random passwords'''

    startup_script = open(
    os.path.join(
      os.path.dirname(__file__), startup_script), 'r').read()

    #Generate two random passwords
    pg_pw = pw_gen(24)
    db_srv_pw = pw_gen(24)

    pg_pw_script = "'" + pg_pw + "';"
    db_srv_pw_script = "'" + db_srv_pw + "';"


    #Find default passwords in bash script and replace with python string formatting variables
    startup_script = re.sub(r'(?<=postgres WITH PASSWORD ).*;', pg_pw_script, startup_script)
    startup_script = re.sub(r'(?<=db_srv WITH PASSWORD ).*;', db_srv_pw_script, startup_script)


    db_id = build(name, startup_script, centos7_img)

    #Get the ID of new instance for further info
    filter_id = 'id=' + db_id
    result = compute.instances().list(project=project, zone=zone, filter=filter_id).execute()

    #Generate names for generated passwords based on server name, last 4 of ID, and account name
    pg_pw_file = result['items'][0]['name'] + '_' + result['items'][0]['id'][-4:] + '_postgres'
    db_srv_pw_file = result['items'][0]['name'] + '_' + result['items'][0]['id'][-4:] + '_db_srv'

    #Call function to save passwords to admin machine
    save_pw(pg_pw, pg_pw_file)
    save_pw(db_srv_pw, db_srv_pw_file)
       
    #Return nessecary info for django setup
    return {'ip': result['items'][0]['networkInterfaces'][0]['networkIP'], 'db_srv_pw': db_srv_pw, 'id': db_id}

#Ingest django bash install script and make necessary changes
def django(startup_script, name, db_info):
    '''Install django from django-install.sh bash script'''

    startup_script = open(
    os.path.join(
      os.path.dirname(__file__), startup_script), 'r').read()
    db_pw = '\'' + db_info['db_srv_pw'] + '\' ,'
    db_host = '\'' + db_info['ip'] + '\' ,'
    startup_script = re.sub(r'(?<=\'PASSWORD\': ).*,', db_pw, startup_script)
    startup_script = re.sub(r'(?<=\'HOST\': ).*,', db_host, startup_script)

    django_id = build(name, startup_script, centos7_img)


    filter_id = 'id=' + django_id

    result = compute.instances().list(project=project, zone=zone, filter=filter_id).execute()

    return result

#Generates random passwords.
#THIS IS ONLY CRYPOGRAPHICALLY SECURE BECAUSE IT USES SystemRandom!
def pw_gen(length):
    '''Generate random password of arbitrary length - only uses letters and numbers. Length >20 recommended'''
    char_gen = random.SystemRandom()
    char_map = string.ascii_letters + string.digits
    return ''.join([ char_gen.choice(char_map) for _ in xrange(length) ])

#Create a directory and save generated passwords ensuring restrictive permissions.
def save_pw(new_pass, name):
    '''Make sure that a directory exists and write the password to a file
    with restrictive permissions for human use.'''
    
    user_home = os.path.expanduser('~'+os.environ['LOGNAME']+'/')
    if not os.path.isdir(
      os.path.join(user_home, pw_dir)):
      print('Making directory to store passwords. You should be able to find them in your home directory in the folder .script_passwd')
      os.makedirs(os.path.join(user_home, pw_dir), 0700)
    else:
      print('password stored in $HOME/.script_passwd/')

    os.umask(0)  #This is critical!!
    with os.fdopen(os.open(os.path.join(user_home, pw_dir, name), os.O_WRONLY | os.O_CREAT, 0o600), 'w') as pw_file:
        pw_file.write(new_pass)

def write_metadata(key_name, value):
  '''write a new key value pair to project wide metadata'''

  request = compute.projects().get(project=project).execute()
  try:
    cur_meta = request['commonInstanceMetadata']['items']
  except KeyError:
    cur_meta = []
  fingerprint = request['commonInstanceMetadata']['fingerprint']
  cur_meta.append({'key':key_name, 'value':value})
  
  body = {'fingerprint': fingerprint, 'items': cur_meta}

  print('writing new metadata with:')
  print(body)

  result = compute.projects().setCommonInstanceMetadata(project=project, body=body).execute()


def check_ready(id):
  '''check meta-data server to see if the finished key is written - check twice then return'''

  id = "id=" + str(id)
  i = 0
  while i < 2:
    result = compute.instances().list(project=project, zone=zone, filter=id).execute()
    keys = []
    for i in result['items'][0]['metadata']['items']:
      keys.append(i['key'])
    if 'finished' in keys:
      print('%s is finished.' % result['items'][0]['name'])
      return True
    else:
      print('%s is not ready yet' % result['items'][0]['name'])
      time.sleep(10)
  return False

if __name__ == '__main__':
  ldap_info = ldap_server('ldap-install.sh', 'ldap-nti310-srv')
  write_metadata('ldap_ip', ldap_info['ip'])
  nfs_info = nfs_server('nfs-server.sh', 'nfs-nti310-srv')
  write_metadata('nfs_ip', nfs_info['ip'])
  db_info = postgres('pgsql-install.sh', 'postgres-nti310-srv')

  services = [ldap_info, nfs_info, db_info]

  while len(services) > 0:

    for i in services:
      if check_ready(i['id']):
        services.pop(i)
        if i == ldap_info:
          ldap_client('ldap-client.sh', 'ldap-nti310-clnt')
        elif i == nfs_info:
          nfs_client('nfs-client.sh', 'nfs-client-nti310-clnt')
        elif i == db_info:
          django('django-install.sh', 'django-nti310-clnt', db_info)
        else:
          sleep(1)