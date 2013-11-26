module orson


function Message = -> 
  DynamicObject(): subject(""): sender(null)

function Actor = |env| {

  let actor = DynamicObject():
    env(env):
    mailbox(java.util.concurrent.ConcurrentLinkedQueue()):
    listening(false):
    define("start", |this| {
      this: listening(true)
      let w = env: spawn(|signal| {
        # Listening
        while this: listening() { 
          if this: mailbox(): size() > 0  { # you've got a mail
            this: onReceive(this: mailbox(): poll())
          } # end if
        } # end while
      }) # end of w
      # Start listening
      w: send("listen")
      return this
    }):
    define("tell", |this, message| {
      this: mailbox(): offer(message)
      return this
    }):
    define("onReceive", |this, message| {})

    return actor
}

function CircularQueue = -> DynamicObject():
  queue1(java.util.concurrent.ConcurrentLinkedQueue()):
  queue2(java.util.concurrent.ConcurrentLinkedQueue()):
  define("offer", |this, t| -> this: queue1(): offer(t)):
  define("poll", |this| {
    if this: queue1():size() == 0 {
      this: queue1(): addAll(this: queue2())
      this: queue2(): clear()
    }
    let r = this: queue1(): poll()
    this: queue2(): offer(r)
    return r
  })