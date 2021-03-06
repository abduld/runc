#!/usr/bin/env bats

load helpers

function setup() {
  teardown_busybox
  setup_busybox
}

function teardown() {
  teardown_busybox
}

function startup_events() {
  ("$RUNC" events test_busybox > events.log)
}

@test "events --stats" {
  # start busybox detached
  run "$RUNC" start -d --console /dev/pts/ptmx test_busybox
  [ "$status" -eq 0 ]

  # check state
  wait_for_container 15 1 test_busybox

  # generate stats 
  run "$RUNC" events --stats test_busybox
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == [\{]"\"type\""[:]"\"stats\""[,]"\"id\""[:]"\"test_busybox\""[,]* ]]
  [[ "${lines[0]}" == *"CgroupStats"* ]]
}

@test "events --interval default " {
  # start busybox detached
  run "$RUNC" start -d --console /dev/pts/ptmx test_busybox
  [ "$status" -eq 0 ]

  # check state
  wait_for_container 15 1 test_busybox
  
  # spawn two sub processes (shells) 
  # the first sub process is an event logger that sends stats events to events.log 
  # the second sub process waits for an event that incudes test_busybox then 
  # kills the test_busybox container which causes the event logger to exit
  ("$RUNC" events test_busybox > events.log) &
  ( 
    retry 10 1 eval "grep -q 'test_busybox' events.log"
    teardown_running_container test_busybox
  ) &
  wait # wait for the above sub shells to finish  
  
  [ -e events.log ]
  
  run cat events.log
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == [\{]"\"type\""[:]"\"stats\""[,]"\"id\""[:]"\"test_busybox\""[,]* ]]
  [[ "${lines[0]}" == *"CgroupStats"* ]]
}

@test "events --interval 1s " {
  # start busybox detached
  run "$RUNC" start -d --console /dev/pts/ptmx test_busybox
  [ "$status" -eq 0 ]

  # check state
  wait_for_container 15 1 test_busybox
  
  # spawn two sub processes (shells) 
  # the first sub process is an event logger that sends stats events to events.log once a second 
  # the second sub process tries 3 times for an event that incudes test_busybox 
  # pausing 1s between each attempt then kills the test_busybox container which 
  # causes the event logger to exit
  ("$RUNC" events --interval 1s test_busybox > events.log) &
  ( 
    retry 3 1 eval "grep -q 'test_busybox' events.log"
    teardown_running_container test_busybox
  ) &
  wait # wait for the above sub shells to finish  
  
  [ -e events.log ]
  
  run eval "grep -q 'test_busybox' events.log"
  [ "$status" -eq 0 ]
}

@test "events --interval 100ms " {
  # start busybox detached
  run "$RUNC" start -d --console /dev/pts/ptmx test_busybox
  [ "$status" -eq 0 ]

  # check state
  wait_for_container 15 1 test_busybox
  
  #prove there is no carry over of events.log from a prior test
  [ ! -e events.log ]
    
  # spawn two sub processes (shells) 
  # the first sub process is an event logger that sends stats events to events.log once every 100ms 
  # the second sub process tries 3 times for an event that incudes test_busybox 
  # pausing 100s between each attempt then kills the test_busybox container which 
  # causes the event logger to exit
  ("$RUNC" events --interval 100ms test_busybox > events.log) &
  ( 
    retry 3 0.100 eval "grep -q 'test_busybox' events.log"
    teardown_running_container test_busybox
  ) &
  wait # wait for the above sub shells to finish  
  
  [ -e events.log ]
  
  run eval "grep -q 'test_busybox' events.log"
  [ "$status" -eq 0 ]
}
