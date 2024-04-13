-- Tablespace: ts_data_pagservicios
-- LOCATION 'D:\\tblspace\\fs_data_ctas_recaudadoras';

  CREATE TABLESPACE ts_data_ctas_recaudadoras
  OWNER postgres
  LOCATION '/var/lib/postgresql/data/fs_data_ctas_recaudadoras';
  
----------------------------------------------------------------------------------------------------
 
DROP SCHEMA IF EXISTS esq_ctas_recaudadoras CASCADE;
CREATE SCHEMA esq_ctas_recaudadoras AUTHORIZATION postgres;

----------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS esq_ctas_recaudadoras.TBL_MOVIMIENTOS;

DROP SEQUENCE IF EXISTS esq_ctas_recaudadoras."SEQ_TBL_MOVIMIENTOS";


CREATE SEQUENCE esq_ctas_recaudadoras."SEQ_TBL_MOVIMIENTOS"
   INCREMENT 1
   START 1
   MINVALUE 1
   MAXVALUE 99999
   CACHE 1;
ALTER SEQUENCE esq_ctas_recaudadoras."SEQ_TBL_MOVIMIENTOS" OWNER TO postgres;

----------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS esq_ctas_recaudadoras.TBL_MOVIMIENTOS;
DROP TABLE IF EXISTS esq_ctas_recaudadoras.TBL_CUENTAS;
DROP TABLE IF EXISTS esq_ctas_recaudadoras.TBL_CLIENTES;


CREATE TABLE esq_ctas_recaudadoras.TBL_CLIENTES(
  codigo VARCHAR(15) NOT NULL,-- ruc
  nombres VARCHAR(200) NULL
)TABLESPACE ts_data_ctas_recaudadoras;
ALTER TABLE IF EXISTS esq_ctas_recaudadoras.TBL_CLIENTES ADD CONSTRAINT XPKTBL_CLIENTES PRIMARY KEY(codigo);

CREATE TABLE esq_ctas_recaudadoras.TBL_CUENTAS(
   cuenta VARCHAR(20) NOT NULL,
   descripcion VARCHAR(120) NOT NULL,
   cliente VARCHAR(15) NOT NULL, 
   monto NUMERIC NOT NULL DEFAULT 0.0
)TABLESPACE ts_data_ctas_recaudadoras;
ALTER TABLE IF EXISTS esq_ctas_recaudadoras.TBL_CUENTAS ADD CONSTRAINT XPKTBL_CUENTAS PRIMARY KEY(cuenta);
ALTER TABLE IF EXISTS esq_ctas_recaudadoras.TBL_CUENTAS ADD CONSTRAINT R1 FOREIGN KEY(cliente) REFERENCES esq_ctas_recaudadoras.TBL_CLIENTES(codigo);


CREATE TABLE esq_ctas_recaudadoras.TBL_MOVIMIENTOS(
   codigo INTEGER NOT NULL,
   cuenta VARCHAR(20) NOT NULL,
   monto NUMERIC NOT NULL DEFAULT 0.0,
   transaccion VARCHAR(5)NOT NULL,
   fechamov TIMESTAMP NOT NULL,
   causalmov VARCHAR(120) NOT NULL,
   deudor VARCHAR(15) NOT NULL
) TABLESPACE ts_data_ctas_recaudadoras;
ALTER TABLE IF EXISTS esq_ctas_recaudadoras.TBL_MOVIMIENTOS ADD CONSTRAINT XPKTBL_MOVIMIENTOS PRIMARY KEY(codigo);
ALTER TABLE IF EXISTS esq_ctas_recaudadoras.TBL_MOVIMIENTOS ALTER COLUMN codigo SET DEFAULT nextval('esq_ctas_recaudadoras."SEQ_TBL_MOVIMIENTOS"');
ALTER TABLE IF EXISTS esq_ctas_recaudadoras.TBL_MOVIMIENTOS ADD CONSTRAINT R2 FOREIGN KEY(cuenta) REFERENCES esq_ctas_recaudadoras.TBL_CUENTAS(cuenta);

----------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION esq_ctas_recaudadoras.fn_abono_cuenta(
  in_cuenta VARCHAR(20),
  in_monto NUMERIC, 
  in_cliente  VARCHAR(15),
  in_transaccion VARCHAR(5),
  in_causalmov VARCHAR(120),
  in_deudor VARCHAR(15)
  ) RETURNS VARCHAR(120) AS $$
 DECLARE resultado VARCHAR(20);
 DECLARE v_transaccion VARCHAR(20);
 DECLARE v_monto NUMERIC;
 
 BEGIN
    resultado:='0000';
   
	if not exists (select cuenta from esq_ctas_recaudadoras.TBL_CUENTAS where cuenta=in_cuenta)
	 then
	  RAISE EXCEPTION 'Nonexistent Cuenta --> %', in_cuenta;
	end if;
	if not exists (select cuenta from esq_ctas_recaudadoras.TBL_CUENTAS where cliente=in_cliente)
	 then
	  RAISE EXCEPTION 'No existe cliente --> %', in_cliente;
	end if;
	
     
	  if in_monto>0
	  then
	      select monto into v_monto from esq_ctas_recaudadoras.TBL_CUENTAS where cuenta=in_cuenta;
          v_monto:=v_monto+in_monto;
	      UPDATE esq_ctas_recaudadoras.TBL_CUENTAS SET monto = v_monto where cuenta=in_cuenta ;
		  INSERT  INTO esq_ctas_recaudadoras.TBL_MOVIMIENTOS(cuenta,monto,transaccion,fechamov,causalmov,deudor) VALUES(in_cuenta,in_monto,in_transaccion,current_timestamp,in_causalmov,in_deudor); 
		  return resultado || '- Proceso Conforme ';
	  else
	       RAISE EXCEPTION 'Saldo insuficiente para pagar deuda --> %', in_monto;
	  end if;  

  	
	EXCEPTION WHEN others then
    return SQLSTATE || '-' || SQLERRM;
 END;
 
  $$ LANGUAGE plpgsql;
 
CREATE OR REPLACE FUNCTION esq_ctas_recaudadoras.fn_reversa_abono_cuenta(
  in_transaccion VARCHAR(5)
  ) RETURNS VARCHAR(120) AS $$
 DECLARE resultado VARCHAR(5);
 DECLARE v_monto NUMERIC;
 DECLARE v_cuenta VARCHAR(20);
 BEGIN
    resultado:='0000';
	if not exists (select cuenta from esq_ctas_recaudadoras.TBL_MOVIMIENTOS where transaccion=in_transaccion)
	 then
	  RAISE EXCEPTION 'No existent id Transaccion --> %', in_transaccion;
	end if;
    select cuenta,monto into v_cuenta, v_monto from esq_ctas_recaudadoras.TBL_MOVIMIENTOS where transaccion=in_transaccion;
	UPDATE esq_ctas_recaudadoras.TBL_CUENTAS SET monto = (monto-v_monto) where cuenta=v_cuenta;
	INSERT  INTO esq_ctas_recaudadoras.TBL_MOVIMIENTOS(cuenta,monto,transaccion,fechamov,causalmov,deudor,idtrxrversa) (select cuenta,monto,nextval('SEQ_PAGO_ID') as transaccion, current_timestamp as fechamov, 'reversion' as causalmov,deudor,transaccion as idtrxrversa from esq_ctas_recaudadoras.TBL_MOVIMIENTOS cr WHERE cr.transaccion=in_transaccion); 
	
	return resultado || '- Proceso Conforme '; 
  	
	EXCEPTION WHEN others then
    return SQLSTATE || '-' || SQLERRM;
 END
 
 $$ LANGUAGE plpgsql;

 -----------------------------------------------------------------------------------------------------------

delete from esq_ctas_recaudadoras.TBL_CUENTAS;
delete from esq_ctas_recaudadoras.TBL_CLIENTES;
delete from esq_ctas_recaudadoras.TBL_MOVIMIENTOS;
--select * from esq_ctas_clientes.TBL_CLIENTES;
--select * from esq_ctas_recaudadoras.TBL_CUENTAS;

insert INTO esq_ctas_recaudadoras.TBL_CLIENTES(codigo,nombres) VALUES('20602649412','Empresa UBRBAN SAC');
insert INTO esq_ctas_recaudadoras.TBL_CUENTAS(cuenta,descripcion,cliente,monto) VALUES ('11206060709890','CUENTA RECAUDADORA','20602649412',10000);


--select  esq_ctas_recaudadoras.fn_abono_cuenta('11206060709890',10,'20602649412','10001','PGTR-DEUDA DE TELEFONO','15865658', )
--select * from esq_ctas_clientes.TBL_MOVIMIENTOS;

------------------------------------------------------------------------------------------------------------------
ALTER TABLE esq_ctas_recaudadoras.TBL_MOVIMIENTOS ADD COLUMN idtrxrversa VARCHAR(5) NULL;




