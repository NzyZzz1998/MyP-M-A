CREATE TABLE tenants (
  id BIGINT PRIMARY KEY,
  name VARCHAR(120) NOT NULL
);

CREATE TABLE export_jobs (
  id BIGINT PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  requested_by BIGINT NOT NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'pending',
  filter_json TEXT NULL,
  file_path VARCHAR(500) NULL,
  error_message TEXT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);
