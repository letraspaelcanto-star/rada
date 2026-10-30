# frozen_string_literal: true

require File.expand_path('../../agency_crm_spec_helper', __dir__)

# ADR 0002 / brief Sprint 3.5 ítem 9: el merge de contactos no puede fallar por
# los deals del mergee ni perderlos; los borrados (contacto, conversación,
# empresa, usuario) nullifican sus vínculos en vez de bloquearse o arrastrar
# el registro CRM.
RSpec.describe AgencyCrm::ContactMergeExtension do
  let(:account) { create(:account) }
  let(:pipeline) { create_agency_pipeline(account) }
  let(:stage) { create_agency_stage(pipeline, name: 'Nuevo') }
  let(:base_contact) { create(:contact, account: account) }
  let(:mergee_contact) { create(:contact, account: account) }

  def create_deal(contact, title: 'Cama Centuris', **overrides)
    AgencyCrm::Deal.create!({ account: account, pipeline: pipeline, stage: stage, contact: contact, title: title }
                            .merge(overrides))
  end

  def merge_contacts!
    ContactMergeAction.new(account: account, base_contact: base_contact, mergee_contact: mergee_contact).perform
  end

  describe 'merge de contactos con deals' do
    it 'pasa los deals del mergee al base y destruye el mergee' do
      deal = create_deal(mergee_contact)

      expect { merge_contacts! }.to change { deal.reload.contact_id }.to(base_contact.id)
        .and change(Contact, :count).by(-1)
      expect(Contact.exists?(mergee_contact.id)).to be(false)
    end

    it 'dos abiertos en el mismo pipeline quedan los dos, marcados, con tarea en el mas nuevo' do
      base_deal = create_deal(base_contact, title: 'Deal del base')
      mergee_deal = create_deal(mergee_contact, title: 'Deal del mergee')
      assignee = create(:user, account: account)
      mergee_deal.update_columns(assignee_id: assignee.id, created_at: 1.minute.from_now)

      merge_contacts!

      expect(account.agency_crm_deals).to contain_exactly(base_deal, mergee_deal)
      [base_deal, mergee_deal].each do |duplicate|
        expect(duplicate.activities.where(kind: :system_event, actor_type: :system).pluck(:body))
          .to include(described_class::DUPLICATE_NOTE)
      end
      task = AgencyCrm::Task.find_by!(title: described_class::DUPLICATE_TASK_TITLE)
      expect(task.deal).to eq(mergee_deal)
      expect(task.assignee).to eq(assignee)
    end

    it 'no colisiona si el deal del base en ese pipeline no esta abierto' do
      base_deal = create_deal(base_contact, status: :won)
      mergee_deal = create_deal(mergee_contact)

      merge_contacts!

      expect(mergee_deal.reload.contact_id).to eq(base_contact.id)
      expect(base_deal.activities.where(body: described_class::DUPLICATE_NOTE)).to be_empty
      expect(mergee_deal.activities.where(body: described_class::DUPLICATE_NOTE)).to be_empty
    end

    it 'el deal de otra cuenta que apunta al mergee no se mueve: queda con contacto en NULL' do
      other_account = create(:account)
      other_pipeline = create_agency_pipeline(other_account, name: 'Pipeline ajeno')
      other_stage = create_agency_stage(other_pipeline, name: 'Nuevo')
      foreign_deal = AgencyCrm::Deal.create!(account: other_account, pipeline: other_pipeline, stage: other_stage,
                                             contact: mergee_contact, title: 'Deal ajeno')
      own_deal = create_deal(mergee_contact)

      merge_contacts!

      expect(own_deal.reload.contact_id).to eq(base_contact.id)
      expect(foreign_deal.reload.contact_id).to be_nil
    end
  end

  describe 'borrados sin efecto dominó (ADR 0002)' do
    let!(:deal) { create_deal(base_contact) }

    it 'borrar el contacto deja el deal con contacto NULL' do
      expect { base_contact.destroy! }.not_to change(AgencyCrm::Deal, :count)
      expect(deal.reload.contact_id).to be_nil
    end

    it 'borrar la conversación pone conversation_id en NULL de deals y tareas' do
      conversation = create(:conversation, account: account)
      deal.update_columns(conversation_id: conversation.id)
      task = AgencyCrm::Task.create!(account: account, conversation: conversation, title: 'Llamar al cliente')

      expect { conversation.destroy! }.not_to change { [AgencyCrm::Deal.count, AgencyCrm::Task.count] }
      expect(deal.reload.conversation_id).to be_nil
      expect(task.reload.conversation_id).to be_nil
    end

    it 'borrar la empresa pone company_id en NULL del deal' do
      company = create(:company, account: account)
      deal.update_columns(company_id: company.id)

      expect { company.destroy! }.not_to change(AgencyCrm::Deal, :count)
      expect(deal.reload.company_id).to be_nil
    end

    it 'borrar el usuario pone assignee en NULL de deals y tareas y destruye sus membresías de board' do
      agent = create(:user, account: account)
      deal.update_columns(assignee_id: agent.id)
      task = AgencyCrm::Task.create!(account: account, assignee: agent, title: 'Llamar al cliente')
      AgencyCrm::BoardMembership.create!(account: account, pipeline: pipeline, user: agent, role: :editor)

      expect { agent.destroy! }.to change(AgencyCrm::BoardMembership, :count).by(-1)
      expect(deal.reload.assignee_id).to be_nil
      expect(task.reload.assignee_id).to be_nil
    end
  end
end
