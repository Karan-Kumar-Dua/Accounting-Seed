global with sharing class XChildRelationshipPicklist extends VisualEditor.DynamicPickList {
    VisualEditor.DesignTimePageContext context;

    global XChildRelationshipPicklist(VisualEditor.DesignTimePageContext context){
        this.context = context;
    }

    global override VisualEditor.DataRow getDefaultValue(){
        VisualEditor.DataRow defaultValue = new VisualEditor.DataRow('Id', 'Id');
        return defaultValue;
    }
    global override VisualEditor.DynamicPickListRows getValues() {
        VisualEditor.DynamicPickListRows childRelationshipValues = new VisualEditor.DynamicPickListRows();
        Schema.DescribeSObjectResult describeSobjects = ((SObject) (Type.forName('Schema.' + this.context.entityName).newInstance())).getSObjectType().getDescribe();
        List<Schema.ChildRelationship> childRelationships = describeSobjects.getChildRelationships();
        for(Schema.ChildRelationship cr : childRelationships){
            //TODO: Describe Label of Relationship
            string iSchemaPath = cr.getChildSObject() + '.' + cr.getField();
            childRelationshipValues.addRow(new VisualEditor.DataRow( iSchemaPath + ' (' + cr.getRelationshipName() + ')', iSchemaPath));
        }
        return childRelationshipValues;
    }
}