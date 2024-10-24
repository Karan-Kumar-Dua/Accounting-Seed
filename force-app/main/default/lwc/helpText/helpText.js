import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

export default class HelpText extends LightningElement {
    
    @api objectApiName;
    @api fieldApiName;

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    objectInfo;

    get helpText() {
        if (this.objectInfo 
            && this.objectInfo.data 
            && this.objectInfo.data.fields 
            && this.objectInfo.data.fields[this.fieldApiName]
        ) {
            return this.objectInfo.data.fields[this.fieldApiName].inlineHelpText;
        }
        return undefined;
    }

    get hasHelpText() {
        return this.helpText ? true : false;
    }
}