/**
 * EventFlow Web Interface
 * 参加者向けタスク選択・ステータス更新アプリケーション
 */

// ========================================
// Firebase設定と初期化
// ========================================

// Firebase設定（実際の値は環境に応じて設定してください）
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_AUTH_DOMAIN",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_STORAGE_BUCKET",
    messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
    appId: "YOUR_APP_ID"
};

// Firebase初期化
try {
    firebase.initializeApp(firebaseConfig);
    console.log('Firebase initialized successfully');
} catch (error) {
    console.error('Firebase initialization error:', error);
    showError('Firebase接続エラーが発生しました。ページを再読み込みしてください。');
}

// ========================================
// グローバル変数
// ========================================

let firestoreClient = null;
let currentEventId = null;
let participantName = null;
let tasks = [];
let currentTaskIndex = 0;
let myTasks = [];
let swipeStartX = 0;
let swipeStartY = 0;
let isDragging = false;

// ========================================
// DOM要素の取得
// ========================================

const nameInputSection = document.getElementById('name-input-section');
const taskCardsSection = document.getElementById('task-cards-section');
const statusPanelSection = document.getElementById('status-panel-section');
const participantNameInput = document.getElementById('participant-name');
const nameSubmitBtn = document.getElementById('name-submit-btn');
const taskCardsContainer = document.getElementById('task-cards');
const loadingElement = document.getElementById('loading');
const completionMessage = document.getElementById('completion-message');
const viewStatusBtn = document.getElementById('view-status-btn');
const backToTasksBtn = document.getElementById('back-to-tasks-btn');
const myTasksList = document.getElementById('my-tasks-list');
const markPaidBtn = document.getElementById('mark-paid-btn');
const errorMessage = document.getElementById('error-message');
const errorText = document.getElementById('error-text');
const errorCloseBtn = document.getElementById('error-close-btn');
const toast = document.getElementById('toast');
const toastText = document.getElementById('toast-text');

// ========================================
// 初期化処理
// ========================================

document.addEventListener('DOMContentLoaded', () => {
    initializeApp();
});

function initializeApp() {
    // URLからイベントIDを取得
    const urlParams = new URLSearchParams(window.location.search);
    currentEventId = urlParams.get('eventId');
    
    if (!currentEventId) {
        showError('イベントIDが見つかりません。正しいURLでアクセスしてください。');
        return;
    }
    
    // FirestoreClientを初期化
    try {
        firestoreClient = new FirestoreClient(currentEventId);
        if (!firestoreClient.isConnected()) {
            throw new Error('Firestore connection failed');
        }
    } catch (error) {
        console.error('FirestoreClient initialization error:', error);
        showError('データベース接続に失敗しました。ページを再読み込みしてください。');
        return;
    }
    
    // LocalStorageから参加者名を取得
    const savedName = localStorage.getItem(`eventflow_participant_${currentEventId}`);
    if (savedName) {
        participantName = savedName;
        participantNameInput.value = savedName;
    }
    
    // イベントリスナーの設定
    setupEventListeners();
    
    console.log('App initialized with eventId:', currentEventId);
}

function setupEventListeners() {
    // 名前入力
    nameSubmitBtn.addEventListener('click', handleNameSubmit);
    participantNameInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            handleNameSubmit();
        }
    });
    
    // ステータス表示ボタン
    viewStatusBtn.addEventListener('click', showStatusPanel);
    backToTasksBtn.addEventListener('click', showTaskCards);
    
    // 支払い完了ボタン
    markPaidBtn.addEventListener('click', handleMarkPaid);
    
    // エラーメッセージ閉じる
    errorCloseBtn.addEventListener('click', hideError);
}

// ========================================
// 参加者名入力処理
// ========================================

function handleNameSubmit() {
    const name = participantNameInput.value.trim();
    
    if (!name) {
        showError('名前を入力してください');
        return;
    }
    
    if (name.length > 50) {
        showError('名前は50文字以内で入力してください');
        return;
    }
    
    participantName = name;
    localStorage.setItem(`eventflow_participant_${currentEventId}`, name);
    
    // タスク選択画面へ遷移
    nameInputSection.classList.add('hidden');
    taskCardsSection.classList.remove('hidden');
    
    // タスクを読み込む
    loadTasks();
}

// ========================================
// タスク読み込み
// ========================================

async function loadTasks() {
    if (!firestoreClient || !firestoreClient.isConnected()) {
        showError('データベース接続エラー');
        return;
    }
    
    showLoading();
    
    try {
        // FirestoreClientを使用してリアルタイムリスナーを設定
        firestoreClient.observeTasks(
            (updatedTasks) => {
                tasks = updatedTasks;
                hideLoading();
                renderCurrentTask();
            },
            (error) => {
                console.error('Error loading tasks:', error);
                hideLoading();
                showError('タスクの読み込みに失敗しました');
            }
        );
        
    } catch (error) {
        console.error('Error in loadTasks:', error);
        hideLoading();
        showError('タスクの読み込み中にエラーが発生しました');
    }
}

// ========================================
// タスクカード表示
// ========================================

function renderCurrentTask() {
    // すべてのタスクを確認済みの場合
    if (currentTaskIndex >= tasks.length) {
        showCompletionMessage();
        return;
    }
    
    const task = tasks[currentTaskIndex];
    
    // タスクカードを作成
    const card = createTaskCard(task);
    
    // 既存のカードをクリア
    taskCardsContainer.innerHTML = '';
    taskCardsContainer.appendChild(card);
    
    // スワイプイベントを設定
    setupSwipeEvents(card, task);
}

function createTaskCard(task) {
    const card = document.createElement('div');
    card.className = 'task-card';
    
    // タスクが既に割り当てられている場合
    const isUnavailable = task.assignedTo && task.assignedTo !== participantName;
    if (isUnavailable) {
        card.classList.add('task-unavailable');
    }
    
    // 優先度の日本語表示
    const priorityText = {
        high: '高',
        medium: '中',
        low: '低'
    };
    
    card.innerHTML = `
        <div class="task-card-header">
            <span class="task-priority ${task.priority}">${priorityText[task.priority] || task.priority}</span>
            ${isUnavailable ? '<span class="task-status">割り当て済み</span>' : ''}
        </div>
        <h3 class="task-title">${escapeHtml(task.title)}</h3>
        <p class="task-description">${escapeHtml(task.description || '')}</p>
        ${isUnavailable ? `<span class="task-unavailable-badge">担当: ${escapeHtml(task.assignedTo)}</span>` : ''}
    `;
    
    return card;
}

function setupSwipeEvents(card, task) {
    // タッチイベント
    card.addEventListener('touchstart', handleSwipeStart, { passive: true });
    card.addEventListener('touchmove', handleSwipeMove, { passive: false });
    card.addEventListener('touchend', (e) => handleSwipeEnd(e, task));
    
    // マウスイベント（デスクトップ用）
    card.addEventListener('mousedown', handleSwipeStart);
    card.addEventListener('mousemove', handleSwipeMove);
    card.addEventListener('mouseup', (e) => handleSwipeEnd(e, task));
    card.addEventListener('mouseleave', (e) => {
        if (isDragging) {
            handleSwipeEnd(e, task);
        }
    });
}

function handleSwipeStart(e) {
    isDragging = true;
    const touch = e.touches ? e.touches[0] : e;
    swipeStartX = touch.clientX;
    swipeStartY = touch.clientY;
    
    const card = e.currentTarget;
    card.classList.add('swiping');
}

function handleSwipeMove(e) {
    if (!isDragging) return;
    
    const touch = e.touches ? e.touches[0] : e;
    const deltaX = touch.clientX - swipeStartX;
    const deltaY = touch.clientY - swipeStartY;
    
    // 縦スクロールを優先
    if (Math.abs(deltaY) > Math.abs(deltaX)) {
        return;
    }
    
    e.preventDefault();
    
    const card = e.currentTarget;
    const rotation = deltaX / 20;
    card.style.transform = `translateX(${deltaX}px) rotate(${rotation}deg)`;
    card.style.opacity = 1 - Math.abs(deltaX) / 300;
}

function handleSwipeEnd(e, task) {
    if (!isDragging) return;
    
    isDragging = false;
    const touch = e.changedTouches ? e.changedTouches[0] : e;
    const deltaX = touch.clientX - swipeStartX;
    
    const card = e.currentTarget;
    card.classList.remove('swiping');
    
    const threshold = 100;
    
    if (Math.abs(deltaX) > threshold) {
        if (deltaX > 0) {
            // 右スワイプ: タスクを引き受ける
            handleTaskClaim(card, task);
        } else {
            // 左スワイプ: スキップ
            handleTaskSkip(card);
        }
    } else {
        // 元の位置に戻す
        card.style.transform = '';
        card.style.opacity = '';
    }
}

// ========================================
// タスク操作
// ========================================

async function handleTaskClaim(card, task) {
    // 既に割り当てられている場合はスキップ
    if (task.assignedTo && task.assignedTo !== participantName) {
        handleTaskSkip(card);
        return;
    }
    
    card.classList.add('swipe-right');
    
    try {
        // FirestoreClientを使用してタスクを引き受ける
        await firestoreClient.claimTask(task.id, participantName);
        
        // 参加者を追加（存在しない場合）
        await firestoreClient.addParticipantIfNotExists(participantName);
        
        showToast('タスクを引き受けました！');
        
        // 次のタスクへ
        setTimeout(() => {
            currentTaskIndex++;
            renderCurrentTask();
        }, 400);
        
    } catch (error) {
        console.error('Error claiming task:', error);
        showError('タスクの更新に失敗しました');
        card.classList.remove('swipe-right');
        card.style.transform = '';
        card.style.opacity = '';
    }
}

function handleTaskSkip(card) {
    card.classList.add('swipe-left');
    
    setTimeout(() => {
        currentTaskIndex++;
        renderCurrentTask();
    }, 400);
}

// ========================================
// ステータスパネル
// ========================================

function showStatusPanel() {
    taskCardsSection.classList.add('hidden');
    statusPanelSection.classList.remove('hidden');
    loadMyTasks();
}

function showTaskCards() {
    statusPanelSection.classList.add('hidden');
    taskCardsSection.classList.remove('hidden');
}

async function loadMyTasks() {
    if (!firestoreClient || !participantName) return;
    
    try {
        // FirestoreClientを使用して自分のタスクを取得
        myTasks = await firestoreClient.getParticipantTasks(participantName);
        
        renderMyTasks();
        
        // FirestoreClientを使用して支払い情報を取得
        const participantData = await firestoreClient.getParticipant(participantName);
        
        if (participantData) {
            document.getElementById('payment-amount').textContent = 
                `支払い額: ¥${participantData.expectedPayment || 0}`;
            
            if (participantData.paymentStatus === 'paid') {
                markPaidBtn.textContent = '支払い済み';
                markPaidBtn.disabled = true;
            }
        }
        
    } catch (error) {
        console.error('Error loading my tasks:', error);
        showError('タスクの読み込みに失敗しました');
    }
}

function renderMyTasks() {
    myTasksList.innerHTML = '';
    
    if (myTasks.length === 0) {
        myTasksList.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">まだタスクを引き受けていません</p>';
        return;
    }
    
    myTasks.forEach((task) => {
        const taskItem = document.createElement('div');
        taskItem.className = 'my-task-item';
        
        const isCompleted = task.status === 'completed';
        
        taskItem.innerHTML = `
            <div class="my-task-header">
                <h4 class="my-task-title">${escapeHtml(task.title)}</h4>
                <input 
                    type="checkbox" 
                    class="task-complete-checkbox" 
                    ${isCompleted ? 'checked' : ''}
                    data-task-id="${task.id}"
                >
            </div>
            <p style="color: var(--text-secondary); font-size: 0.9rem; margin-bottom: 0.5rem;">
                ${escapeHtml(task.description || '')}
            </p>
            <textarea 
                class="task-note-input" 
                placeholder="メモを追加..."
                data-task-id="${task.id}"
            >${escapeHtml(task.note || '')}</textarea>
        `;
        
        myTasksList.appendChild(taskItem);
    });
    
    // イベントリスナーを設定
    document.querySelectorAll('.task-complete-checkbox').forEach((checkbox) => {
        checkbox.addEventListener('change', handleTaskStatusChange);
    });
    
    document.querySelectorAll('.task-note-input').forEach((textarea) => {
        textarea.addEventListener('blur', handleTaskNoteChange);
    });
}

async function handleTaskStatusChange(e) {
    const taskId = e.target.dataset.taskId;
    const isCompleted = e.target.checked;
    
    try {
        // FirestoreClientを使用してステータスを更新
        const status = isCompleted ? 'completed' : 'in_progress';
        await firestoreClient.updateTaskStatus(taskId, status);
        
        showToast(isCompleted ? 'タスクを完了しました' : 'タスクを進行中に戻しました');
        
    } catch (error) {
        console.error('Error updating task status:', error);
        showError('ステータスの更新に失敗しました');
        e.target.checked = !isCompleted;
    }
}

async function handleTaskNoteChange(e) {
    const taskId = e.target.dataset.taskId;
    const note = e.target.value.trim();
    
    try {
        // FirestoreClientを使用してメモを更新
        await firestoreClient.updateTaskStatus(taskId, null, note);
        
        showToast('メモを保存しました');
        
    } catch (error) {
        console.error('Error updating task note:', error);
        showError('メモの保存に失敗しました');
    }
}

async function handleMarkPaid() {
    if (!participantName) return;
    
    try {
        // FirestoreClientを使用して支払いステータスを更新
        await firestoreClient.updatePaymentStatus(participantName, 'paid');
        
        markPaidBtn.textContent = '支払い済み';
        markPaidBtn.disabled = true;
        showToast('支払いを完了しました');
        
    } catch (error) {
        console.error('Error marking payment:', error);
        showError('支払いステータスの更新に失敗しました');
    }
}

// ========================================
// UI ヘルパー関数
// ========================================

function showLoading() {
    loadingElement.classList.remove('hidden');
    taskCardsContainer.classList.add('hidden');
    completionMessage.classList.add('hidden');
}

function hideLoading() {
    loadingElement.classList.add('hidden');
    taskCardsContainer.classList.remove('hidden');
}

function showCompletionMessage() {
    taskCardsContainer.classList.add('hidden');
    completionMessage.classList.remove('hidden');
}

function showError(message) {
    errorText.textContent = message;
    errorMessage.classList.remove('hidden');
    
    // 5秒後に自動で閉じる
    setTimeout(hideError, 5000);
}

function hideError() {
    errorMessage.classList.add('hidden');
}

function showToast(message) {
    toastText.textContent = message;
    toast.classList.remove('hidden');
    
    // 3秒後に自動で閉じる
    setTimeout(() => {
        toast.classList.add('hidden');
    }, 3000);
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
