//cardknox
import businessServiceLabel from '@salesforce/label/c.CRDKNX_BUSINESS_SERVICE_LABEL';
import electricalPartsLabel from '@salesforce/label/c.CRDKNX_ELECTRICAL_PARTS_LABEL';
import hvacLabel from '@salesforce/label/c.CRDKNX_HVAC_LABEL';
import professionalServiceLabel from '@salesforce/label/c.CRDKNX_PROFESSIONAL_SERVICE_LABEL';
import legalServiceLabel from '@salesforce/label/c.CRDKNX_LEGAL_SERVICE_LABEL';
import softwareLabel from '@salesforce/label/c.CRDKNX_SOFTWARE_LABEL';
import otherLabel from '@salesforce/label/c.CRDKNX_OTHER_LABEL';


const tierLabels = {
    formatLabel: function (label, args) {
        return label.replace(/{(\d+)}/gm, (match, index) => {
            return args[index] === undefined ? '' : `${args[index]}`;
        });
    },
    businessServiceLabel,
    electricalPartsLabel,
    hvacLabel,
    professionalServiceLabel,
    legalServiceLabel,
    softwareLabel,
    otherLabel,
}
export {tierLabels};