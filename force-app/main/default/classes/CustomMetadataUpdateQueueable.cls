public with sharing class CustomMetadataUpdateQueueable implements Queueable {

    public List<CustomSettingConfig> metaDataUpdatesJSON;

    public CustomMetadataUpdateQueueable(List<CustomSettingConfig> metaDataUpdatesJSON) {
          this.metaDataUpdatesJSON = metaDataUpdatesJSON;
    }

    public void execute(QueueableContext context) {
        try{           
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            for(CustomSettingConfig mdUpdate: metaDataUpdatesJSON){
                //fetch customMetadata by its label
                Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
                customMetadata.fullName = 'Binding.'+mdUpdate.label;
                customMetadata.label = mdUpdate.label;
                
                //dynamically add values in field that needs to update/insert using map of fieldApiName and related value in it
                for (String key: mdUpdate.fieldWithValuesMap.keySet()) {
                    //fetch custommetadatavalue which denotes metadta fields to update/insert value in it
                    Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
                    customField.field = key;
                    customField.value = mdUpdate.fieldWithValuesMap.get(key);
                    customMetadata.values.add(customField);
                }

                mdContainer.addMetadata(customMetadata);
            }
                Metadata.Operations.enqueueDeployment(mdContainer, null);
        }
        catch(Exception ex){
            throw new DomainUtils.UtilityException(Label.INTERNAL_ERR_MSG + ' ' + Label.INF_IN_ITS_METADATA);
        }
    }
}