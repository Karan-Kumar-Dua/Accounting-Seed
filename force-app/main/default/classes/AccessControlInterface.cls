public interface AccessControlInterface { 
    Boolean isFeatureEnabled(); 
    Set<Schema.SObjectType> getSObjectsGrants(); 
    Map<Schema.SObjectType, List<Schema.SObjectField>> getFieldGrants();
    String getFieldLabels(List<Schema.SObjectField> fields); 
}