import React, { useState } from "react";

import { ITeam } from "interfaces/team";
import Modal from "components/modals/Modal";
import Spinner from "components/loaders/Spinner";
import UserForm from "../UserForm";
import { IFormData } from "../UserForm/UserForm";

interface ICreateUserModalProps {
  onCancel: () => void;
  onSubmit: (formData: IFormData) => void;
  defaultGlobalRole?: string | null;
  defaultTeamRole?: string;
  defaultTeams?: ITeam[];
  availableTeams: ITeam[];
  isPremiumTier: boolean;
  smtpConfigured: boolean;
  currentTeam?: ITeam;
  canUseSso: boolean; // corresponds to whether SSO is enabled for the organization
  isModifiedByGlobalAdmin?: boolean | false;
  isFormSubmitting?: boolean | false;
}

const baseClass = "create-user-modal";

const DEFAULT_CREATE_USER_ERRORS = {
  email: null,
  name: null,
  password: null,
  sso_enabled: null,
};

const CreateUserModal = (props: ICreateUserModalProps): JSX.Element => {
  const {
    onCancel,
    onSubmit,
    currentTeam,
    defaultGlobalRole,
    defaultTeamRole,
    defaultTeams,
    availableTeams,
    isPremiumTier,
    smtpConfigured,
    canUseSso,
    isModifiedByGlobalAdmin,
    isFormSubmitting,
  } = props;

  const [createUserErrors, setCreateUserErrors] = useState(
    DEFAULT_CREATE_USER_ERRORS
  );

  console.log("availableTeams: ", availableTeams);
  console.log("isModifiedByGlobalAdmin: ", isModifiedByGlobalAdmin);

  return (
    <Modal title="Create user" onExit={onCancel} className={baseClass}>
      <>
        {isFormSubmitting && (
          <div className="loading-spinner">
            <Spinner />
          </div>
        )}
        <UserForm
          defaultGlobalRole={defaultGlobalRole}
          defaultTeamRole={defaultTeamRole}
          defaultTeams={defaultTeams}
          onCancel={onCancel}
          onSubmit={onSubmit}
          availableTeams={availableTeams}
          submitText={"Save"}
          isPremiumTier={isPremiumTier}
          smtpConfigured={smtpConfigured}
          canUseSso={canUseSso}
          isModifiedByGlobalAdmin={isModifiedByGlobalAdmin}
          serverErrors={createUserErrors}
          currentTeam={currentTeam}
          isNewUser
        />
      </>
    </Modal>
  );
};

export default CreateUserModal;
