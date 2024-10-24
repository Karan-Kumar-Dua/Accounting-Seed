export default {
    columns: [{"apiName": "Name", "label": "Billing Line Name", "type": "text"}, {
        "apiName": "AcctSeed__Date__c",
        "label": "Date",
        "type": "date",
        "typeAttributes": {"month": "2-digit", "day": "2-digit", "year": "numeric", "timeZone": "UTC"}
    }, {
        "apiName": "AcctSeed__Product__c",
        "label": "Product",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__Product__r.Name"},
            "referenceObject": "Product2",
            "relationshipName": "AcctSeed__Product__r",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__Hours_Units__c",
        "label": "Quantity",
        "type": "number",
        "typeAttributes": {"minimumFractionDigits": 6}
    }, {
        "apiName": "AcctSeed__Rate__c",
        "label": "Unit Price",
        "type": "currency"
    }, {
        "apiName": "AcctSeed__Sub_Total__c",
        "label": "Sub-Total",
        "type": "currency"
    }, {
        "apiName": "AcctSeed__Tax_Rate__c",
        "label": "Tax Rate",
        "type": "percent"
    }, {
        "apiName": "AcctSeed__Tax_Amount2__c",
        "label": "Tax Amount",
        "type": "currency"
    }, {
        "apiName": "AcctSeed__Total__c",
        "label": "Total",
        "type": "currency"
    }, {
        "apiName": "AcctSeed__Revenue_GL_Account__c",
        "label": "Revenue GL Account",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__Revenue_GL_Account__r.Name"},
            "referenceObject": "AcctSeed__GL_Account__c",
            "relationshipName": "AcctSeed__Revenue_GL_Account__r",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__Tax_Group__c",
        "label": "Tax Group",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__Tax_Group__r.Name"},
            "referenceObject": "AcctSeed__Tax_Group__c",
            "relationshipName": "AcctSeed__Tax_Group__r",
            "target": "_self"
        }
    }],
    drawer: [{
        "apiName": "AcctSeed__Project__c",
        "label": "Project",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__Project__r.Name"},
            "referenceObject": "AcctSeed__Project__c",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__Project_Task__c",
        "label": "Project Task",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__Project_Task__r.Name"},
            "referenceObject": "AcctSeed__Project_Task__c",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__GL_Account_Variable_1__c",
        "label": "GL Variable 1",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__GL_Account_Variable_1__r.Name"},
            "referenceObject": "AcctSeed__Accounting_Variable__c",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__GL_Account_Variable_2__c",
        "label": "GL Variable 2",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__GL_Account_Variable_2__r.Name"},
            "referenceObject": "AcctSeed__Accounting_Variable__c",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__GL_Account_Variable_3__c",
        "label": "GL Variable 3",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__GL_Account_Variable_3__r.Name"},
            "referenceObject": "AcctSeed__Accounting_Variable__c",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__GL_Account_Variable_4__c",
        "label": "GL Variable 4",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__GL_Account_Variable_4__r.Name"},
            "referenceObject": "AcctSeed__Accounting_Variable__c",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__Time_Card_Variable_1__c",
        "label": "Time Card Variable 1",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__Time_Card_Variable_1__r.Name"},
            "referenceObject": "AcctSeed__Accounting_Variable__c",
            "target": "_self"
        }
    }, {
        "apiName": "AcctSeed__Time_Card_Variable_2__c",
        "label": "Time Card Variable 2",
        "type": "reference",
        "typeAttributes": {
            "label": {"fieldName": "AcctSeed__Time_Card_Variable_2__r.Name"},
            "referenceObject": "AcctSeed__Accounting_Variable__c",
            "target": "_self"
        }
    }],
    actions: [{
        "icon": "utility:edit",
        "name": "edit",
        "label": "Edit",
        "variant": "border-filled",
        "alternativeText": "Edit",
        "global": true
    }, {
        "icon": "utility:save",
        "name": "save",
        "label": "Save",
        "variant": "border-filled",
        "alternativeText": "Save",
        "global": true
    }, {
        "icon": "utility:animal_and_nature",
        "name": "animals",
        "label": "Custom Animal Action",
        "variant": "border-filled",
        "alternativeText": "Custom Animal Button",
        "global": false
    }, {
        "icon": "utility:download",
        "name": "csv",
        "label": "CSV",
        "variant": "border-filled",
        "alternativeText": "CSV",
        "global": true
    }],
    tableData: [{
        "Name": "BL-00000",
        "AcctSeed__Date__c": "2022-01-14",
        "AcctSeed__Product__c": "01t3F00000A7lOEQAZ",
        "AcctSeed__Hours_Units__c": 1,
        "AcctSeed__Rate__c": 1000,
        "AcctSeed__Sub_Total__c": 1000,
        "AcctSeed__Tax_Rate__c": 0,
        "AcctSeed__Tax_Amount2__c": 0,
        "AcctSeed__Total__c": 1000,
        "AcctSeed__Revenue_GL_Account__c": "a0g3F000002nuUAQAY",
        "Id": "a0L3F000004rDjQUAU",
        "AcctSeed__Product__r": {"Name": "GenWatt Diesel 1000kW", "Id": "01t3F00000A7lOEQAZ"},
        "AcctSeed__Revenue_GL_Account__r": {"Name": "4000-Product Revenue", "Id": "a0g3F000002nuUAQAY"}
    }, {
        "Name": "BL-00001",
        "AcctSeed__Date__c": "2022-01-17",
        "AcctSeed__Product__c": "01t3F00000A7lOGQAZ",
        "AcctSeed__Hours_Units__c": 5,
        "AcctSeed__Rate__c": 1250,
        "AcctSeed__Sub_Total__c": 6250,
        "AcctSeed__Tax_Rate__c": 0,
        "AcctSeed__Tax_Amount2__c": 0,
        "AcctSeed__Total__c": 6250,
        "AcctSeed__Revenue_GL_Account__c": "a0g3F000002nuUAQAY",
        "Id": "a0L3F000004rDjRUAU",
        "AcctSeed__Product__r": {"Name": "GenWatt Gasoline 750kW", "Id": "01t3F00000A7lOGQAZ"},
        "AcctSeed__Revenue_GL_Account__r": {"Name": "4000-Product Revenue", "Id": "a0g3F000002nuUAQAY"}
    }, {
        "Name": "BL-00002",
        "AcctSeed__Date__c": "2022-01-04",
        "AcctSeed__Product__c": "01t3F00000A7lODQAZ",
        "AcctSeed__Hours_Units__c": 12,
        "AcctSeed__Rate__c": 1739,
        "AcctSeed__Sub_Total__c": 20868,
        "AcctSeed__Tax_Rate__c": 0,
        "AcctSeed__Tax_Amount2__c": 0,
        "AcctSeed__Total__c": 20868,
        "AcctSeed__Revenue_GL_Account__c": "a0g3F000002nuUAQAY",
        "Id": "a0L3F000004rDjSUAU",
        "AcctSeed__Product__r": {"Name": "GenWatt Propane 1500kW", "Id": "01t3F00000A7lODQAZ"},
        "AcctSeed__Revenue_GL_Account__r": {"Name": "4000-Product Revenue", "Id": "a0g3F000002nuUAQAY"}
    }]
}