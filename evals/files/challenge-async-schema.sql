CREATE TABLE export_jobs (
  id BIGINT PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  requested_by BIGINT NOT NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'pending',
  request_json JSON NOT NULL,
  result_url VARCHAR(500) NULL,
  error_message TEXT NULL,
  retry_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_export_jobs_tenant_status
  ON export_jobs (tenant_id, status);

-- Existing worker code also writes processing and retrying, but neither value
-- has a documented transition contract. Duplicate requests are not guarded.
