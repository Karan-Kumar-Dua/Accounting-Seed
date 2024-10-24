import {api, LightningElement} from 'lwc';

export default class StandaloneLightningSpinner extends LightningElement {
    @api
    spinnerText = '';
    @api
    size = "large"; //small, medium & large
    @api
    variant = "base" //base, brand,inverse
    @api
    alternativeText = "Loading";
}