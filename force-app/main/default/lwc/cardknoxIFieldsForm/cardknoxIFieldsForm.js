import { LightningElement, track } from 'lwc';

export default class CardknoxIFieldsForm extends LightningElement {
    
    get fullUrl() {
        return '/apex/AcctSeed__CardknoxIFieldsForm';
    }
    iframeOnload() {
        console.log('Loaded');
    }
    // async connectedCallback() {
    //     Promise.all([
    //         loadScript(this, IFieldsResource),
    //     ]).then(() => {
    //         IFieldsResource.setAccount("ifields_accounseeddevb45d3f99ffb2415cb33c4ced", "AcctSeed", "1.0.0");
    //     });
    // }
    // handleSubmit() {
    //     Promise.all([
    //         loadScript(this, IFieldsResource ),
    //     ]).then(() => {
    //         IFieldsResource.getTokens(
    //             function () { 
    //                 document.getElementById('card-token').innerHTML = document.querySelector("[data-ifields-id='card-number-token']").value;
    //                 document.getElementById('cvv-token').innerHTML = document.querySelector("[data-ifields-id='cvv-token']").value;
    //             },
    //             function() { //onError
    //             },
    //             5000, //5 second timeout
    //         );
    //     }).catch( error => {
    //         console.log(error);
    //     });
    // }
}