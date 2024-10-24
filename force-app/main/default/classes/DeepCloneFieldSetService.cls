/**
 * Deepclonefieldset service class which will provide the support to all the 
 * deepclone classes when they need filtered createable fields from the created fieldset
 */
public with sharing class DeepCloneFieldSetService {
    // return only those fields which the current user can actually clone
    public static Set<String> getCloneableFields(String objectName, String fieldSetName){
        FieldSetHandler fsh = new FieldSetHandler(new FieldSetHandler.FieldSetRequest(
                                objectName,
                                fieldSetName,
                                '',
                                ''
                            ));
        return getCloneableFields(fsh.response);
    }
    // filter the fields and return
    private static Set<String> getCloneableFields(FieldSetHandler.FieldSetResponse fieldsResponse){
        Set<String> cloneableFields = new Set<String>();

        for(FieldSetHandler.FieldSetColumn column : fieldsResponse.mainColumns){
            if(column.updateable && column.isCreateable && !column.isUnique){
                cloneableFields.add(column.apiName);
            }
        }
        return cloneableFields;
    }
}