//FieldSelectionModal JS
import { api,track  } from 'lwc';
import LightningModal from 'lightning/modal';

export default class FieldsSelectionModal extends LightningModal {
    @api allFields;
    @track availableFields = []
    @track selectedFields = []
    initialAvailbleFields = []
    initialSelectedFields = []
    labels = [];

    connectedCallback(){
        if(this.allFields != null){
            console.log('allFields ',this.allFields);
            this.allFields.forEach((item)=>{
                this.availableFields.push(this.processItem(item))
                if('AcctSeed__Add_Field__c' in item && item.AcctSeed__Add_Field__c){
                    this.selectedFields.push(item.Id) 
                }
            })
            this.initialAvailbleFields =  this.availableFields;
            this.initialSelectedFields =  this.selectedFields;
        }
        
        console.log('allFields ',this.allFields)
        console.log('selectedFields  ',this.selectedFields)
        console.log('availableFields ',this.availableFields)
   }

    get isFieldsSelected(){
        console.log('in getter')
        /* if length not equal */
        if(this.initialSelectedFields.length != this.selectedFields.length){
            console.log('false')
            return false;
        }
        console.log('this.this.initialSelectedFields -> ',JSON.parse(JSON.stringify(this.initialSelectedFields)) ,' this.selectedFields -> ',JSON.parse(JSON.stringify(this.selectedFields)))
        /* If length but one is removed and one is added change in list content */
        return !this.initialSelectedFields.some(field => !this.selectedFields.includes(field))

    }

    handleFieldSelection(event){
        this.selectedFields = event.detail.value;
        console.log('selectedOptionsList ',this.selectedFields);
    }

    processItem(item){
        return {label : item.AcctSeed__label__c, value : item.Id}
    }
    
    AddFieldsToDatatable(){
        //send array of selected and deselected  fields in list
        const fieldsToRemove = this.initialSelectedFields.filter(item => !this.selectedFields.includes(item))
        console.log('field to remove ',fieldsToRemove)
        this.close({fieldsToAdd : this.selectedFields, fieldsToRemove : fieldsToRemove})
    }
}