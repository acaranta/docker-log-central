#!/usr/bin/env coffee

VERSION = '0.0.1'

getopt = require('node-getopt').create([
    ['l', 'log', 'output logs as they arrive'],
    ['h', 'help', 'show this help'],
    ['v', 'version', 'show program version']
])
.bindHelp()
.parseSystem()

if getopt.options.version
    return console.log('Docker-Log-Central ' + VERSION)

opts =
    docker_url:     '/var/run/docker.sock'
    env:            getopt.options.env              || []

Docker = require('dockerode')
colors = require('colors')
domain = require('domain')
fs     = require('fs')
net    = require('net')
dgram  = require('dgram')

syslog_host  = process.env.SYSLOG_HOST  || '127.0.0.1'
syslog_port  = process.env.SYSLOG_PORT  || '514'
syslog_proto = process.env.SYSLOG_PROTO || 'tcp'

# Init syslog connection depending on the protocol
initiateSyslog = (proto, host, port) ->
  if (proto == 'tcp')
    connection = net.createConnection syslog_port, syslog_host
    connection.on 'connect', () ->
    console.log((".. Opened connection to #{syslog_host}:#{syslog_port}/#{syslog_proto}").green)
    connection.on 'error', (err) ->
      console.log(("xx Error connecting to #{syslog_host}:#{syslog_port}/#{syslog_proto}").yellow)
      delay 1000, -> connection.connect syslog_port, syslog_host
    connection.on 'end', (data) ->
      console.log(('Server lost ... Retrying...').yellow)
      delay 1000, -> connection.connect syslog_port, syslog_host
    return connection
  else if (proto == 'udp')
    connection = dgram.createSocket('udp4')
    console.log((".. Socket Ready to #{syslog_host}:#{syslog_port}/#{syslog_proto}").green)
    return connection
#Initialize Outgoing log connection
connection = initiateSyslog(syslog_proto, syslog_host, syslog_port)

#Docker logging Mgmt
console.log('.. initializing docker-log-central (hit ^C to quit)')

# first check if we are running inside a docker container
docker_container_id = null

data = fs.readFileSync '/proc/self/cgroup'

re = /docker\/([a-f0-9]{64})/
res = re.exec(data)

if res != null
    docker_container_id = res[1]
    console.log('.. running inside docker container ' + docker_container_id.substr(0, 12).yellow)

if opts.docker_url.indexOf(':') != -1
    dockerOpts = opts.docker_url.split(':')
    dockerOpts = { host: dockerOpts[0], port: dockerOpts[1] }
else
    dockerOpts = { socketPath: opts.docker_url }

docker = new Docker(dockerOpts)
fragment_ids = {};

# Attaching to already running con
console.log('.. attaching already running containers')
docker.listContainers null, (err, containers) ->
    return unless containers
    containers.forEach (data) ->
        attach(docker.getContainer(data.Id))

# Event manager to attach to new containers        
docker.getEvents(null, (err, stream) ->
    throw err if err
    console.log((' ✓ connected to docker at "' + opts.docker_url + '"').green)
    
    stream.on('data', (data) ->
        data = JSON.parse(data)

        #console.log(data) 
        if data.status != 'create'
            return
#Debug command to dump new containers infos      
#        (docker.getContainer(data.id)).inspect((err,info) -> console.log(info))
        attach(docker.getContainer(data.id))
    )
)

######################
#Functions Definition
######################



#Format syslog TimeStamp
formatSyslogDate = (unixtime) ->
  months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun','Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  date = new Date(unixtime)
  return [months[(date.getMonth()+1)],("0000"+date.getDate()).substr(-2,2)].join(' ') + ' ' + [("0"+date.getHours()).substr(-2,2), ("0"+date.getMinutes()).substr(-2,2), ("0"+date.getSeconds()).substr(-2,2)].join(":")

#Used to delay/wait before doing something
delay = (ms, func) -> setTimeout func, ms

#used to send message
send_log = (socket, msg) ->
	socket.write msg

#used to send syslog message
send_syslog = (socket, host, port, proto, date, container, msg) ->
  criticity = 5
  facility = 1
  message = '<' + criticity + facility + '>' + date + ' ' + container.id.substr(0,12) + ' dockerlogger: ' + msg
  if (proto == 'tcp')
    socket.write(message)
  else if (proto == 'udp')
    console.log('Sending UDP log') 
    msg = new Buffer(message)
    socket.send(msg, 0, message.length, port, host)
    
#Attach to the container to get its logs
attach = (container) ->
    domain.create().on('error', (err) ->
        # most of the time it's dockerode replaying the callback when the connection is reset
        # see dockerode/lib/modem.js:87
        throw err unless err.code == 'ECONNRESET'
    ).run(->
        container.inspect((err, info) ->
            throw err if err

            if container.id == docker_container_id
                console.log('.. not attaching ' + container.id.substr(0, 12).yellow + ' since it is us')
                return

            use_multiplexing = not info.Config.Tty

            env = {}

            if info.Config.Env and opts.env.length > 0
                for evar in info.Config.Env
                    evar = evar.split '='
                    for name in opts.env
                        if evar[0] == name
                            env[evar[0]] = evar[1]

            console.log('<- attaching container ' + container.id.substr(0, 12).yellow)

            container.attach({ logs: false, stream: true, stdin: false, stdout: true, stderr: true }, (err, stream) ->
                throw err if err

                stream.on('end', ->
                    delete fragment_ids[container.id]
                    console.log('-> detaching container ' + container.id.substr(0, 12).yellow)
                )

                fragment_ids[container.id] = 0

                stream.on('data', (packet) ->

                    try
                        parse_packet(packet, use_multiplexing, (frame) ->
                            fragment_id = fragment_ids[container.id]++

                            if getopt.options.log
                                process.stdout.write(fragment_id + '> ' + frame.content)

                            message = {
                                container: container.id,
                                fragment_id: fragment_id,
                                env: env,
                                type: frame.type,
                                length: frame.length,
                                content: frame.content,
                                timestamp: Date.now()
                                syslogtime: formatSyslogDate(Date.now())
                            }
			    # Do something with the log ;)
#                            send_log(connection, JSON.stringify(message))
                            send_syslog(connection, syslog_host, syslog_port, syslog_proto, formatSyslogDate(Date.now()), container, frame.content)
                        )
                    catch e
                        console.log 'could not parse packet: '.red + e.message
                        console.log packet
                )
            )
        )
    )

parse_packet = (packet, use_multiplexing, callback) ->
    if !use_multiplexing
        return [null, Buffer.byteLength(packet, 'utf8'), line]

    offset = 0

    buf = new Buffer(packet)

    while offset < buf.length

        type = buf.readUInt8(offset)
        length = buf.readUInt32BE(offset + 4)
        content = buf.toString('utf8', offset + 8, offset + 8 + length)

        if not type in [0, 1, 2]
            throw new Error('Unknown stream type ' + frame.type)

        callback { type: type, length: length, content: content }

        offset = offset + 8 + length

String::padLeft = (padValue) ->
    String(padValue + this).slice(-padValue.length)
