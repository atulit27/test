trigger Milestone1_Project_Trigger on Milestone1_Project__c (before update, before delete, before insert ) {
    
    if( Trigger.isUpdate ){
        Milestone1_Project_Trigger_Utility.handleProjectUpdateTrigger(trigger.new);
    } 
    else if( Trigger.isDelete ) {
        Milestone1_Project_Trigger_Utility.handleProjectDeleteTrigger(trigger.old);
    }
    else if( Trigger.isInsert ) {
        Milestone1_Project_Trigger_Utility.handleProjectInsertTrigger( trigger.new );
    }

}