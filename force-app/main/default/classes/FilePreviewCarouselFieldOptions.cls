global with sharing class FilePreviewCarouselFieldOptions extends VisualEditor.DynamicPickList {
    VisualEditor.DesignTimePageContext context;

    global FilePreviewCarouselFieldOptions(VisualEditor.DesignTimePageContext context){
        this.context = context;
    }

    global override VisualEditor.DataRow getDefaultValue() {
        VisualEditor.DataRow defaultValue = new VisualEditor.DataRow('Id', 'Id');
        return defaultValue;
    }
    global override VisualEditor.DynamicPickListRows getValues() {
        VisualEditor.DynamicPickListRows childRelationshipValues = new VisualEditor.DynamicPickListRows();
        Map<String, Schema.SObjectField> fieldsMap = ((SObject) (Type.forName('Schema.' + this.context.entityName).newInstance())).getSObjectType().getDescribe().fields.getMap();
        for (Schema.SObjectField sObjectField : fieldsMap.values()) {
            DescribeFieldResult field = sObjectField.getDescribe();
            if (String.valueOf(field.getType()) == 'STRING' && field.getLength() >= 36
                    && String.isBlank(field.getCompoundFieldName()) && !field.isCalculated()
                    && !field.isAutoNumber() && !field.isNameField()) {
                childRelationshipValues.addRow(new VisualEditor.DataRow(field.getLabel(), field.getName()));
            }
        }
        return childRelationshipValues;
    }
}