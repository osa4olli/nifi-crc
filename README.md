nifi-crc
========

There are some customizations for running a nifi container in an openshift cluster. Since openshift runs pods on an arbitrary user, we are not able to write in the conf or log directory.
Therewore we use an init container to copy the file from the conf directory to an emptydir volume, so that nifi can write on this directory during start up. We also map all the directories
that nifi needs to write (log, flow repository, etc) to a persistent volume claim.

For running on openshift, there is a build config required, which can look like this:
```
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: nifi
  labels:
    app: nifi
spec:
  source:
    type: Git
    git:
      uri: https://github.com/osa4olli/nifi-crc.git
  strategy:
    type: Docker                      
    dockerStrategy:
      dockerfilePath: Dockerfile    # Look for Dockerfile in: gitUri/contextDir/dockerfilePath
  output:
    to:
      kind: ImageStreamTag
      name: nifi-registry:1.25.0
```
starting from the build config, we use a deployment config for creating the deployment, which can look like this:
```
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  labels:
    app: nifi
  name: nifi
spec:
  replicas: 1
  selector:
    app: nifi
    deploymentconfig: nifi
  strategy:
    resources: {}
    rollingParams:
      intervalSeconds: 1
      maxSurge: 25%
      maxUnavailable: 25%
      timeoutSeconds: 600
      updatePeriodSeconds: 1
    type: Rolling
  template:
    metadata:
      labels:
        app: nifi
        deploymentconfig: nifi
    spec:
      volumes:
        - name: nifi-tk-conf
          emptyDir: {}
        - name: nifi-conf
          emptyDir: {}
        - name: nifi-work
          #emptyDir: {}
          persistentVolumeClaim:
            claimName: myclaim
      containers:
      - image: image-current.openshift-image-registry.svc:5000/ecp/nifi:latest #nifi-registry:latest
        #command: ["sleep","3600"]
        imagePullPolicy: "Always"
        name: nifi
        ports:
        - containerPort: 8443
          protocol: TCP
        resources: {}
        env:
        - name: HOME
          value: /tmp/
        - name: SINGLE_USER_CREDENTIALS_USERNAME
          value: admin
        - name: SINGLE_USER_CREDENTIALS_PASSWORD
          value: <insert a password here or fetch one from a secret>
            #- name: NIFI_JVM_HEAP_MAX
            #value: 512m
        volumeMounts:
        - name: nifi-conf
          mountPath: /opt/nifi/nifi-current/conf/
          subPath: conf
        - name: nifi-tk-conf
          mountPath: /opt/nifi/nifi-toolkit-current/conf/
          subPath: conf
        - name: nifi-work
          mountPath: /opt/nifi/nifi-current/logs/
          subPath: logs
        - name: nifi-work
          mountPath: /opt/nifi/nifi-current/run/
          subPath: run
        - name: nifi-work
          mountPath: /opt/nifi/nifi-current/work/
          subPath: work
        - name: nifi-work
          mountPath: /opt/nifi/nifi-current/flowfile_repository/
          subPath: flowfile_repository
        - name: nifi-work
          mountPath: /opt/nifi/nifi-current/content_repository
          subPath: content_repository
        - name: nifi-work
          mountPath: /opt/nifi/nifi-current/database_repository
          subPath: database_repository
        - name: nifi-work
          mountPath: /opt/nifi/nifi-current/provenance_repository
          subPath: provenance_repository
        - name: nifi-work
          mountPath: /opt/nifi/nifi-current/state
          subPath: state
      initContainers:
        - name: init
          image: image-registry.openshift-image-registry.svc:5000/nifi/nifi:latest #nifi-registry:latest # Docker image
          imagePullPolicy: "Always"
          command:  ["cp","-r","/opt/nifi/nifi-current/conf/","/data/"]
          volumeMounts:
            - mountPath: /data/
              name: nifi-conf
              readOnly: False
        - name: init-tk
          image: image-registry.openshift-image-registry.svc:5000/ecp/nifi:latest
          imagePullPolicy: "Always"
          command: ["cp","-r","/opt/nifi/nifi-toolkit-current/conf/","/data"]
          volumeMounts:
          - mountPath: /data
            name: nifi-tk-conf
            readOnly: False
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      securityContext: {}
      terminationGracePeriodSeconds: 30
  triggers:
  - type: ConfigChange
  - imageChangeParams:
      automatic: true
      containerNames:
      - nifi
      from:
        kind: ImageStreamTag
        name: nifi:latest
    type: ImageChange
```
