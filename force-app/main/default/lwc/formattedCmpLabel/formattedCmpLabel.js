import { LightningElement, api } from 'lwc';
import { LabelService } from 'c/utils';

const BASE_FORM_ELEMENT_STYLE = 'slds-form-element';

export default class FormattedCmpLabel extends LightningElement {
    @api label = '';
    @api inline = false;
    @api variant = 'label-stacked';
    @api hideLabel = false;
    @api required = false;
    labels = LabelService;

    get formElementStyle() {
        return ( BASE_FORM_ELEMENT_STYLE + ( this.inline || this.variant === 'label-inline' ? ' slds-form-element_horizontal' : ' slds-form-element_stacked' ));
    }

    get showLabel() {
        return this.variant !== 'label-hidden';
    }
}