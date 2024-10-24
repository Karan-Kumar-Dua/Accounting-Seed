public with sharing class AccountingSeedCopilot {

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> getContext(){
        SOQLBuilder soql = new SOQLBuilder(Organization.SObjectType);
        soql.selectFields(new List<Schema.SObjectField>{
                Organization.Id,
                Organization.Name,
                Organization.IsSandbox,
                Organization.OrganizationType,
                Organization.InstanceName,
                Organization.LanguageLocaleKey,
                Organization.NamespacePrefix
        });
        soql.setLimit(1);
        Organization org = Database.query(soql.toSOQL());
        
        Map<String, Object> mProps = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(org));
        mProps.remove('attributes');
        mProps.remove('Id');
        mProps.put('OrganizationId', org.Id);
        mProps.put('UserType', UserInfo.getUserType());
        mProps.put('UserName', UserInfo.getUserName());
        mProps.put('UserEmail', UserInfo.getUserEmail());
        mProps.put('UserId', UserInfo.getUserId());
        mProps.put('Environment', org.IsSandbox ? 'UAT' : 'Production');
        return mProps;
    }

}