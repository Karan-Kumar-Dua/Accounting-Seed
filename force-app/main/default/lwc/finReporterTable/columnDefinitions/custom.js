// wrapped in a function to avoid references modifying this data.
import TIMEZONE from "@salesforce/i18n/timeZone";
import Labels from "../labels";
import { LabelService } from "c/utils";

const custom = () => {
  return [{
      label: Labels.INF_REPORT_NUMBER,
      fieldName: 'reportLink',
      type: 'customUrl',
      sortable: true,
      initialWidth: 160,
      typeAttributes: {
        label: {
          fieldName: 'reportName'
        },
        recordName: {
          fieldName: 'reportName'
        },
        showLink: {
          fieldName: 'showReportName'
        },
        target: '_blank'
      },
      cellAttributes: {
        alignment: 'left',
        disabled: true,
      }
    },
    {
      label: LabelService.commonPeriod,
      fieldName: 'endPeriodLink',
      type: 'url',
      sortable: true,
      initialWidth: 100,
      typeAttributes: {
        label: {
          fieldName: 'endPeriodName'
        },
        target: '_blank'
      },
      cellAttributes: {
        alignment: 'left'
      }
    },
    {
      label: Labels.INF_REPORT_NAME_TEXT,
      fieldName: 'reportDefinitionLink',
      type: 'url',
      sortable: true,
      initialWidth: 160,
      typeAttributes: {
        label: {
          fieldName: 'reportDefinitionName'
        },
        target: '_blank'
      },
      cellAttributes: {
        alignment: 'left'
      }
    },
    {
      label: LabelService.commonCurrency,
      fieldName: 'currency',
      type: 'text',
      sortable: true,
      initialWidth: 100,
      typeAttributes: {
        label: {
          fieldName: 'currency'
        },
        target: self
      },
      cellAttributes: {
        alignment: 'left'
      }
    },
    {
      label: LabelService.commonStatus,
      fieldName: 'status',
      type: 'text',
      sortable: true,
      initialWidth: 100,
      typeAttributes: {
        label: {
          fieldName: 'status'
        },
        target: self
      },
      cellAttributes: {
        alignment: 'left'
      }
    },
    {
      label: Labels.INF_COMPLETED_DATE_OR_TIME,
      fieldName: 'completedDateTime',
      type: 'date',
      sortable: true,
      initialWidth: 180,
      typeAttributes: {
        label: {
          fieldName: 'completedDateTime'
        },
        target: self,
        month: '2-digit',
        day: '2-digit',
        hour: "2-digit",
        minute: "2-digit",
        year: 'numeric',
        timeZone: TIMEZONE
      },
      cellAttributes: {
        alignment: 'left'
      }
    },
    {
      label: LabelService.commonCreatedBy,
      fieldName: 'createByLink',
      type: 'url',
      sortable: true,
      initialWidth: 140,
      typeAttributes: {
        label: {
          fieldName: 'createByName'
        },
        target: '_blank'
      },
      cellAttributes: {
        alignment: 'left'
      }
    }
  ]
};

export default custom;