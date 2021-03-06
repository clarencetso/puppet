require 'puppet/indirector/terminus'
require 'puppet/util/queue'
require 'yaml'

# Implements the <tt>:queue</tt> abstract indirector terminus type, for storing
# model instances to a message queue, presumably for the purpose of out-of-process
# handling of changes related to the model.
#
# Relies upon Puppet::Util::Queue for registry and client object management,
# and specifies a default queue type of <tt>:stomp</tt>, appropriate for use with a variety of message brokers.
#
# It's up to the queue client type to instantiate itself correctly based on Puppet configuration information.
# 
# A single queue client is maintained for the abstract terminus, meaning that you can only use one type
# of queue client, one message broker solution, etc., with the indirection mechanism.
#
# Per-indirection queues are assumed, based on the indirection name.  If the <tt>:catalog</tt> indirection makes
# use of this <tt>:queue</tt> terminus, queue operations work against the "catalog" queue.  It is up to the queue
# client library to handle queue creation as necessary (for a number of popular queuing solutions, queue
# creation is automatic and not a concern).
class Puppet::Indirector::Queue < Puppet::Indirector::Terminus
    extend ::Puppet::Util::Queue

    # Queue has no idiomatic "find"
    def find(request)
        nil
    end

    # Place the request on the queue
    def save(request)
        begin
            Puppet.info "Queueing catalog for %s" % request.key
            client.send_message(queue, render(request.instance))
        rescue => detail
            raise Puppet::Error, "Could not write %s to queue: %s\nInstance::%s\n client : %s" % [request.key, detail,request.instance.to_s,client.to_s]
        end
    end

    def self.queue
        indirection_name
    end

    def queue
        self.class.queue
    end

    # Returns the singleton queue client object.
    def client
        self.class.client
    end

    # Formats the model instance associated with _request_ appropriately for message delivery.
    # Uses YAML serialization.
    def render(obj)
        YAML::dump(obj)
    end

    # converts the _message_ from deserialized format to an actual model instance.
    def self.intern(message)
        YAML::load(message)
    end

    # Provides queue subscription functionality; for a given indirection, use this method on the terminus
    # to subscribe to the indirection-specific queue.  Your _block_ will be executed per new indirection
    # model received from the queue, with _obj_ being the model instance.
    def self.subscribe
        client.subscribe(queue) do |msg|
            begin
                yield(self.intern(msg))
            rescue => detail
                # really, this should log the exception rather than raise it all the way up the stack;
                # we don't want exceptions resulting from a single message bringing down a listener
                raise Puppet::Error, "Error occured with subscription to queue %s for indirection %s: %s" % [queue, indirection_name, detail]
            end
        end
    end
end
