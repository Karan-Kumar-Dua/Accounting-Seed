public with sharing class TaskReassign {

    private Task theTask;
    public Task theTaskReassign {get; set;}

    public TaskReassign(ApexPages.StandardController controller) {
        theTask = (Task) controller.getRecord();
        theTaskReassign = new Task();
    }

    public PageReference reassign() {
        try {
            theTask.OwnerId = theTaskReassign.OwnerId;
            SFDCSecurityUtils.updateProxy(theTask);
        }
        catch (Exception ex) {
            ApexPages.addMessages(ex);
            return NULL;
        }
        return new PageReference('/' + theTask.Id);
    }

}