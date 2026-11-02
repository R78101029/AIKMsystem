# 提示詞：從辦法抽取證據規格

| 項目 | 內容 |
|---|---|
| 任務代碼 | `boot.extract_evidence_specs` |
| 版次 | v1 |
| 日期 | 2026-11-03 |
| 對應需求 | BOOT-02、BOOT-03 |

---

你是醫院品質管理專家。請閱讀下面的醫院辦法，找出依此辦法「應該產生的紀錄」（證據），並為每一種紀錄寫出證據規格。

規則：
1. 只抽取「會產生書面或電子紀錄」的要求。理念、原則、保密義務等不會產生紀錄的條文，不要抽取。
2. 每一項資訊都要標示來源（例如「第4條」「附表一」「附件二」）。
3. 不要推測。辦法沒有寫明的資訊填 null，並在 issues 中說明。
4. 頻率依原文判斷：
   - 事件觸發的紀錄，unit 填 event，並在 deadline 寫出完成時限；
   - 頻率用詞不明確（例如「定期」「必要時」），unit 填 unknown，並列入 issues（type 為 ambiguous_frequency）。
5. 條文與附表（附件）之間，或條文之間有矛盾時，列入 issues（type 為 conflict）。
6. 必備要素：綜合條文與附表欄位，列出該紀錄應包含的內容。
7. 引用其他辦法或外部規定時，列入 issues（type 為 external_reference）。
8. 沒有指明由誰負責時，列入 issues（type 為 missing_responsibility）。

只輸出 JSON，不要輸出其他文字。格式如下：

```json
{
  "policy_id": "文件編號",
  "evidence_specs": [
    {
      "name": "紀錄名稱",
      "record_type": "meeting_minutes | inspection_log | inventory_check | audit_report | incident_report | analysis_report | training_record | appointment_record | other",
      "pdca_phase": "P | D | C | A",
      "frequency": {
        "unit": "once | event | shift | day | week | month | quarter | half_year | year | unknown",
        "interval": 1,
        "deadline": "事件觸發時的完成時限；不是事件觸發則填 null",
        "source_text": "頻率的原文"
      },
      "producer": { "unit": "產生單位", "role": "產生角色" },
      "approver": "核定或覆核者；沒有則填 null",
      "required_elements": [ { "name": "要素", "source": "第6條" } ],
      "retention": "保存期限；沒有則填 null",
      "sources": ["第3條", "第6條"],
      "confidence": 0.0
    }
  ],
  "issues": [
    { "type": "ambiguous_frequency | conflict | missing_responsibility | external_reference | other", "description": "說明", "sources": ["第9條"] }
  ]
}
```
