import { LightningElement,api,track } from 'lwc';

export default class XModalMapFieldsHelper extends LightningElement {
    @api field;
    @api fieldValue;
    @api userMapping;
    @track options =[];
    @api get columns(){ return undefined; };
    set columns(value){
        if(value){
            this.options = [];
            value.forEach(col => {
                this.options.push({label : col.label, value: col.apiName});
            });
        }
    }
    handlePicklistChange(evt){
        let picklistChange = new CustomEvent('picklistchange', {
            detail : {
                key : this.field,
                value : evt.target.value,
                userMapping : this.userMapping
            }
        });
        this.dispatchEvent(picklistChange);
    }

}