trigger ASImmediateEvent on AS_Immediate_Event__e (after insert) {
    EventPubSub.consume(Trigger.New);
}