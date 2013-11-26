module pi

import orson
import gololang.concurrent.workers.WorkerEnvironment

function Work = |start, nrOfElements| ->
  DynamicObject(): start(start): nrOfElements(nrOfElements)

# === Result ===
struct Result = { value }

function PiApproximation = |pi, duration| ->
  DynamicObject(): pi(pi): duration(duration)

# Actor : "Pi Worker"
function Worker = |env| ->
  DynamicObject(): mixin(Actor(env)):
    define("calculatePiFor", |this, start, nrOfElements| {
      var acc = 0.0
      for (var i = start * nrOfElements, i <= ((start + 1) * nrOfElements - 1), i = i + 1)  {
        acc =  acc + 4.0 * (1.0 - (i % 2.0) * 2.0) / (2.0 * i + 1.0)
      }
      return acc
    }):
    define("onReceive", |this, message| { # waiting for instance of Work
        let piPart = this: calculatePiFor(message: start(), message: nrOfElements())
        message: sender(): tell(
          Message(): subject("result"): sender(this): result(Result(piPart))
        )
        this: listening(false)
    })

function Master = |env, nrOfWorkers, nrOfMessages, nrOfElements, listener| ->
  DynamicObject(): mixin(Actor(env)):
    poolWorkersEnv(WorkerEnvironment.builder(): withFixedThreadPool(nrOfWorkers)):
    pi(0):
    startedAt(java.lang.System.currentTimeMillis()):
    nrOfResults(0):
    define("onReceive", |this, message| { # waiting for instance of message
      if message: subject(): equals("calculate") {
        # pool of workers
        
        let workers = CircularQueue()

        nrOfWorkers: times({
          workers: offer(
            this: poolWorkersEnv(): spawn(|start|{
              Worker(env): start(): tell(Work(start, nrOfElements): subject("go"): sender(this))
            })
          )
        })

        for (var start = 0, start < nrOfMessages  , start = start + 1)  {

          workers: poll(): send(start)          
        }

      } else {
        if message: subject(): equals("result") {
          this: pi(this: pi() + message: result(): value())
          this: nrOfResults(this: nrOfResults() + 1)
        }
        if this: nrOfResults() == nrOfMessages { # send result to the listener
          let duration = java.lang.System.currentTimeMillis() - this: startedAt()
          listener: tell(PiApproximation(this: pi(), duration): sender(this): subject("piapproximation"))
          this: listening(false)
        }
      } 
    })

function Listener = |env| ->
  DynamicObject(): mixin(Actor(env)):
    define("onReceive", |this, message| { # waiting for instance of PiApproximation
      println("PiApproximation : " + message: pi())
      println("Duration : " + message: duration())
      this: listening(false)
      message: sender(): env(): shutdown()
      message: sender(): poolWorkersEnv(): shutdown()
    })

function main = |args| {

  # WorkerEnvironment.builder(): withFixedThreadPool(n)
  # WorkerEnvironment.builder(): withFixedThreadPool()
  # WorkerEnvironment.builder(): withSingleThreadExecutor() ++
  # WorkerEnvironment.builder(): withCachedThreadPool()

  let env = WorkerEnvironment.builder(): withFixedThreadPool()
  let listener = Listener(WorkerEnvironment.builder(): withFixedThreadPool())
  let master = Master(env, 4, 10000, 10000, listener)

  listener: start()
  master: start()
  master: tell(Message(): subject("calculate"))

}