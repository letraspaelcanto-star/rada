import { onMounted, onUnmounted } from 'vue';
import { createConsumer } from '@rails/actioncable';

import { useStore } from 'dashboard/composables/store';
import { useCrmStore } from 'dashboard/stores/agencyCrm';

// Suscripción de tiempo real del kanban al canal AgencyCrm::PipelineChannel
// (stream pipeline:<account_id>:<pipeline_id>, PLAN-DE-PROYECTO.md §5).
//
// La suscripción vive y muere con la página del board: entras al kanban,
// te conectás; salís, te desconectás. No toca el connector global de RoomChannel.
export const useCrmPipelineCable = getPipelineId => {
  let consumer = null;
  let subscription = null;

  const connect = () => {
    const vuexStore = useStore();
    const crmStore = useCrmStore();
    const currentUser = vuexStore.getters.getCurrentUser || {};
    const accountId = vuexStore.getters.getCurrentAccountId;
    const pipelineId = getPipelineId();
    const { pubsub_token: pubsubToken } = currentUser;
    const { websocketURL = '' } = window.chatwootConfig || {};

    if (!pubsubToken || !accountId || !pipelineId) return;

    consumer = createConsumer(
      websocketURL ? `${websocketURL}/cable` : undefined
    );
    subscription = consumer.subscriptions.create(
      {
        channel: 'AgencyCrm::PipelineChannel',
        pubsub_token: pubsubToken,
        user_id: vuexStore.getters.getCurrentUserID,
        account_id: accountId,
        pipeline_id: pipelineId,
      },
      {
        received: crmStore.handleCableEvent,
      }
    );
  };

  const disconnect = () => {
    subscription?.unsubscribe();
    consumer?.disconnect();
    subscription = null;
    consumer = null;
  };

  onMounted(connect);
  onUnmounted(disconnect);

  return {
    reconnect: () => {
      disconnect();
      connect();
    },
  };
};
