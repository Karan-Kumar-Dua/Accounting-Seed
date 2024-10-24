import { LightningElement, api } from 'lwc';
import commonFeatureDeprecated from '@salesforce/label/c.COMMON_FEATURE_DEPRECATED';

export default class UploadSignatureToBankAccount extends LightningElement {
    @api recordId;
    label = {
        commonFeatureDeprecated
    };
}