trigger ASCommitEvent on AS_Commit_Event__e (after insert) {
    EventPubSub.consume(Trigger.New);
}