askPassScript = '''#!/bin/sh
case "$1" in
Username*) echo $USERNAME ;;
Password*) echo $PASSWORD ;;
esac
'''

credentialsId = ''

def setId(credId) {
  credentialsId = credId
  return credId
}

// This helper runs the specified command with the GIT_ASKPASS env variable set just before
// running. The credential ID must be set before hand or this will throw an error.
def run(label, command) {
  result = ''
  if (credentialsId == '') {
    error 'Must set the GIT credentials ID first with a call to setGitCredId'
  }

  def tmpAskPassScript = pwd(tmp:true) + "/${UUID.randomUUID().toString()}"
  writeFile(file: tmpAskPassScript, text: askPassScript)

  cmd = """chmod +x ${tmpAskPassScript}
GIT_ASKPASS=${tmpAskPassScript} ${command}
rm ${tmpAskPassScript}
"""

  withCredentials([usernamePassword(credentialsId: credentialsId, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {   
    result = sh label: label, script: cmd, returnStdout: true
  }
 result
}

return this
