/**
 * FirestoreClient
 * Firestore操作を管理するクライアントクラス
 * 
 * 責務:
 * - Firestore初期化
 * - タスクのリアルタイム監視
 * - タスクの引き受け（claim）
 * - タスクステータスの更新
 * - 支払いステータスの更新
 * - 参加者の管理
 */

class FirestoreClient {
    /**
     * FirestoreClientのコンストラクタ
     * @param {string} eventId - イベントID
     * @param {Object} firebaseConfig - Firebase設定オブジェクト
     */
    constructor(eventId, firebaseConfig = null) {
        this.eventId = eventId;
        this.db = null;
        this.unsubscribers = [];
        
        // Firebase初期化
        if (firebaseConfig) {
            this.initialize(firebaseConfig);
        } else if (typeof firebase !== 'undefined' && firebase.apps.length > 0) {
            // 既に初期化されている場合
            this.db = firebase.firestore();
        }
    }
    
    /**
     * Firebaseを初期化
     * @param {Object} config - Firebase設定オブジェクト
     * @throws {Error} 初期化に失敗した場合
     */
    initialize(config) {
        try {
            if (typeof firebase === 'undefined') {
                throw new Error('Firebase SDK is not loaded');
            }
            
            // 既に初期化されていない場合のみ初期化
            if (firebase.apps.length === 0) {
                firebase.initializeApp(config);
            }
            
            this.db = firebase.firestore();
            console.log('FirestoreClient initialized successfully');
        } catch (error) {
            console.error('FirestoreClient initialization error:', error);
            throw new Error(`Firestore初期化エラー: ${error.message}`);
        }
    }
    
    /**
     * データベース接続を確認
     * @returns {boolean} 接続されている場合true
     */
    isConnected() {
        return this.db !== null;
    }
    
    /**
     * タスクをリアルタイムで監視
     * @param {Function} callback - タスク更新時に呼ばれるコールバック関数
     * @param {Function} errorCallback - エラー発生時に呼ばれるコールバック関数
     * @returns {Function} リスナーを解除する関数
     */
    observeTasks(callback, errorCallback = null) {
        if (!this.isConnected()) {
            const error = new Error('Database not connected');
            if (errorCallback) errorCallback(error);
            return () => {};
        }
        
        const tasksRef = this.db
            .collection('events')
            .doc(this.eventId)
            .collection('tasks');
        
        const unsubscribe = tasksRef.onSnapshot(
            (snapshot) => {
                const tasks = [];
                snapshot.forEach((doc) => {
                    tasks.push({
                        id: doc.id,
                        ...doc.data()
                    });
                });
                
                // タスクを優先度順にソート
                tasks.sort((a, b) => {
                    const priorityOrder = { high: 0, medium: 1, low: 2 };
                    return (priorityOrder[a.priority] || 999) - (priorityOrder[b.priority] || 999);
                });
                
                callback(tasks);
            },
            (error) => {
                console.error('Error observing tasks:', error);
                if (errorCallback) {
                    errorCallback(error);
                }
            }
        );
        
        this.unsubscribers.push(unsubscribe);
        return unsubscribe;
    }
    
    /**
     * タスクを引き受ける
     * @param {string} taskId - タスクID
     * @param {string} participantName - 参加者名
     * @returns {Promise<void>}
     * @throws {Error} 更新に失敗した場合
     */
    async claimTask(taskId, participantName) {
        if (!this.isConnected()) {
            throw new Error('Database not connected');
        }
        
        if (!taskId || !participantName) {
            throw new Error('taskId and participantName are required');
        }
        
        try {
            await this.db
                .collection('events')
                .doc(this.eventId)
                .collection('tasks')
                .doc(taskId)
                .update({
                    assignedTo: participantName,
                    status: 'assigned',
                    updatedAt: firebase.firestore.FieldValue.serverTimestamp()
                });
            
            console.log(`Task ${taskId} claimed by ${participantName}`);
        } catch (error) {
            console.error('Error claiming task:', error);
            throw new Error(`タスクの引き受けに失敗しました: ${error.message}`);
        }
    }
    
    /**
     * タスクのステータスを更新
     * @param {string} taskId - タスクID
     * @param {string} status - 新しいステータス (unassigned/assigned/in_progress/completed)
     * @param {string} note - オプションのメモ
     * @returns {Promise<void>}
     * @throws {Error} 更新に失敗した場合
     */
    async updateTaskStatus(taskId, status, note = null) {
        if (!this.isConnected()) {
            throw new Error('Database not connected');
        }
        
        if (!taskId) {
            throw new Error('taskId is required');
        }
        
        try {
            const updateData = {
                updatedAt: firebase.firestore.FieldValue.serverTimestamp()
            };
            
            if (status !== null && status !== undefined) {
                const validStatuses = ['unassigned', 'assigned', 'in_progress', 'completed'];
                if (!validStatuses.includes(status)) {
                    throw new Error(`Invalid status: ${status}. Must be one of: ${validStatuses.join(', ')}`);
                }
                updateData.status = status;
            }
            
            if (note !== null && note !== undefined) {
                updateData.note = note;
            }
            
            await this.db
                .collection('events')
                .doc(this.eventId)
                .collection('tasks')
                .doc(taskId)
                .update(updateData);
            
            console.log(`Task ${taskId} updated`);
        } catch (error) {
            console.error('Error updating task:', error);
            throw new Error(`タスクの更新に失敗しました: ${error.message}`);
        }
    }
    
    /**
     * 支払いステータスを更新
     * @param {string} participantName - 参加者名
     * @param {string} paymentStatus - 支払いステータス (paid/unpaid)
     * @param {number} paidAmount - オプションの支払い額
     * @returns {Promise<void>}
     * @throws {Error} 更新に失敗した場合
     */
    async updatePaymentStatus(participantName, paymentStatus, paidAmount = null) {
        if (!this.isConnected()) {
            throw new Error('Database not connected');
        }
        
        if (!participantName || !paymentStatus) {
            throw new Error('participantName and paymentStatus are required');
        }
        
        const validStatuses = ['paid', 'unpaid'];
        if (!validStatuses.includes(paymentStatus)) {
            throw new Error(`Invalid payment status: ${paymentStatus}. Must be one of: ${validStatuses.join(', ')}`);
        }
        
        try {
            const updateData = {
                paymentStatus: paymentStatus,
                updatedAt: firebase.firestore.FieldValue.serverTimestamp()
            };
            
            if (paidAmount !== null) {
                updateData.paidAmount = paidAmount;
            }
            
            await this.db
                .collection('events')
                .doc(this.eventId)
                .collection('participants')
                .doc(participantName)
                .update(updateData);
            
            console.log(`Payment status for ${participantName} updated to ${paymentStatus}`);
        } catch (error) {
            console.error('Error updating payment status:', error);
            throw new Error(`支払いステータスの更新に失敗しました: ${error.message}`);
        }
    }
    
    /**
     * 参加者を追加（存在しない場合のみ）
     * @param {string} participantName - 参加者名
     * @param {number} expectedPayment - 期待支払い額（デフォルト: 0）
     * @returns {Promise<boolean>} 新規作成された場合true、既存の場合false
     * @throws {Error} 追加に失敗した場合
     */
    async addParticipantIfNotExists(participantName, expectedPayment = 0) {
        if (!this.isConnected()) {
            throw new Error('Database not connected');
        }
        
        if (!participantName) {
            throw new Error('participantName is required');
        }
        
        try {
            const participantRef = this.db
                .collection('events')
                .doc(this.eventId)
                .collection('participants')
                .doc(participantName);
            
            const doc = await participantRef.get();
            
            if (!doc.exists) {
                await participantRef.set({
                    name: participantName,
                    expectedPayment: expectedPayment,
                    paymentStatus: 'unpaid',
                    paidAmount: 0,
                    joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
                    updatedAt: firebase.firestore.FieldValue.serverTimestamp()
                });
                
                console.log(`Participant ${participantName} added`);
                return true;
            }
            
            return false;
        } catch (error) {
            console.error('Error adding participant:', error);
            throw new Error(`参加者の追加に失敗しました: ${error.message}`);
        }
    }
    
    /**
     * 特定の参加者のタスクを取得
     * @param {string} participantName - 参加者名
     * @returns {Promise<Array>} タスクの配列
     * @throws {Error} 取得に失敗した場合
     */
    async getParticipantTasks(participantName) {
        if (!this.isConnected()) {
            throw new Error('Database not connected');
        }
        
        if (!participantName) {
            throw new Error('participantName is required');
        }
        
        try {
            const tasksRef = this.db
                .collection('events')
                .doc(this.eventId)
                .collection('tasks');
            
            const snapshot = await tasksRef
                .where('assignedTo', '==', participantName)
                .get();
            
            const tasks = [];
            snapshot.forEach((doc) => {
                tasks.push({
                    id: doc.id,
                    ...doc.data()
                });
            });
            
            return tasks;
        } catch (error) {
            console.error('Error getting participant tasks:', error);
            throw new Error(`タスクの取得に失敗しました: ${error.message}`);
        }
    }
    
    /**
     * 参加者情報を取得
     * @param {string} participantName - 参加者名
     * @returns {Promise<Object|null>} 参加者データ、存在しない場合null
     * @throws {Error} 取得に失敗した場合
     */
    async getParticipant(participantName) {
        if (!this.isConnected()) {
            throw new Error('Database not connected');
        }
        
        if (!participantName) {
            throw new Error('participantName is required');
        }
        
        try {
            const participantRef = this.db
                .collection('events')
                .doc(this.eventId)
                .collection('participants')
                .doc(participantName);
            
            const doc = await participantRef.get();
            
            if (doc.exists) {
                return {
                    id: doc.id,
                    ...doc.data()
                };
            }
            
            return null;
        } catch (error) {
            console.error('Error getting participant:', error);
            throw new Error(`参加者情報の取得に失敗しました: ${error.message}`);
        }
    }
    
    /**
     * 単一のタスクを取得
     * @param {string} taskId - タスクID
     * @returns {Promise<Object|null>} タスクデータ、存在しない場合null
     * @throws {Error} 取得に失敗した場合
     */
    async getTask(taskId) {
        if (!this.isConnected()) {
            throw new Error('Database not connected');
        }
        
        if (!taskId) {
            throw new Error('taskId is required');
        }
        
        try {
            const taskRef = this.db
                .collection('events')
                .doc(this.eventId)
                .collection('tasks')
                .doc(taskId);
            
            const doc = await taskRef.get();
            
            if (doc.exists) {
                return {
                    id: doc.id,
                    ...doc.data()
                };
            }
            
            return null;
        } catch (error) {
            console.error('Error getting task:', error);
            throw new Error(`タスクの取得に失敗しました: ${error.message}`);
        }
    }
    
    /**
     * すべてのリスナーを解除してクリーンアップ
     */
    cleanup() {
        this.unsubscribers.forEach(unsubscribe => {
            if (typeof unsubscribe === 'function') {
                unsubscribe();
            }
        });
        this.unsubscribers = [];
        console.log('FirestoreClient cleaned up');
    }
}

// モジュールとしてエクスポート（Node.js環境用）
if (typeof module !== 'undefined' && module.exports) {
    module.exports = FirestoreClient;
}
