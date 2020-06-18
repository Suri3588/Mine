#!/bin/sh

# generate convert_service_file script to run on each mongo VM
cat > convert_service_file << 'EOF'
#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: $0 mongodb27017_exporter.service"
  exit
fi

function convert_service_file() { 
  filename=$1
  oldname=$1.$(date +"%Y%m%d%H%M%S")
  newname=$1.new

  cat $filename | awk '{
    tt=$0
    for (i=0; i<NF; i++) {
      t = $(i+1)
      if (index(t, "--mongodb.uri=") > 0) {
        split(t,s,"--mongodb.uri=")
        gsub("\\?", "\\?", t)
        sub(t, "", tt)
        print "Environment=MONGODB_URI=" s[2]
      }
    }
    print tt
  }' > $newname

  comp=`diff $newname $filename -q`
  if [ -n "$comp" ]; then
    # create .bak for rollback
    cp $filename $filename.bak
    # create historical file
    mv $filename $oldname
    # rename
    mv $newname $filename
  fi
}

convert_service_file $1
EOF

# Upload convert_service_file script to each mongo VM,
# then execute it for each 27017 and 27016 processes
for ms in 1 2 3
do
  mongo=mongo${ms}
  scp -o "StrictHostKeyChecking=no" convert_service_file ${mongo}:/home/nucleus/convert_service_file
  ssh ${mongo} /bin/bash << 'EOF'
  for num in 27017 27016
  do
	  service=mongodb${num}_exporter.service
	  file=/etc/systemd/system/mongodb${num}_exporter.service
	  echo "sevice:" $service
	  echo "file:" $file
	  if [ -f $file ]; then
		sudo bash ./convert_service_file $file
		ls -al $file
		echo converted.
		echo --------------------------------------------------------------------------------------------------------------
		cat $file
		sudo systemctl daemon-reload
		sudo systemctl restart $service
	  fi
	done
	exit 0
EOF
  ssh ${mongo} ps -elf | grep mongodb_exporter
done