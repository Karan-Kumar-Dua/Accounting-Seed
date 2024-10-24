public with sharing class CustomSettingConfig {
    public String label;
    public Map<String,Object> fieldWithValuesMap;

    public CustomSettingConfig(){}
    
    public CustomSettingConfig(String label, Map<String,Object> fieldWithValuesMap){
        this.label = label;
        this.fieldWithValuesMap = fieldWithValuesMap;
    }
}