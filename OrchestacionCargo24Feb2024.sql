CREATE TABLESPACE ts_data_ctas_clientes
OWNER postgres
LOCATION '/var/lib/postgresql/data/fs_data_ctas_clientes';

-------------------------------------------------------------------------

 DROP SCHEMA IF EXISTS esq_ctas_clientes CASCADE;
CREATE SCHEMA esq_ctas_clientes AUTHORIZATION postgres;

--------------------------------------------------------------------------


DROP TABLE IF EXISTS esq_ctas_clientes.TBL_MOVIMIENTOS;

DROP SEQUENCE IF EXISTS esq_ctas_clientes."SEQ_TBL_MOVIMIENTOS";
DROP SEQUENCE IF EXISTS esq_ctas_clientes."SEQ_TBL_CUENTAS_TRANSACCION";

CREATE SEQUENCE esq_ctas_clientes."SEQ_TBL_MOVIMIENTOS"
   INCREMENT 1
   START 10000
   MINVALUE 10000
   MAXVALUE 99999
   CACHE 1;
ALTER SEQUENCE esq_ctas_clientes."SEQ_TBL_MOVIMIENTOS" OWNER TO postgres;

CREATE SEQUENCE esq_ctas_clientes."SEQ_TBL_CUENTAS_TRANSACCION"
   INCREMENT 1
   START 10000
   MINVALUE 10000
   MAXVALUE 99999
   CACHE 1;
ALTER SEQUENCE esq_ctas_clientes."SEQ_TBL_CUENTAS_TRANSACCION" OWNER TO postgres;

--------------------------------------------------------------------------

DROP TABLE IF EXISTS esq_ctas_clientes.TBL_MOVIMIENTOS;
DROP TABLE IF EXISTS esq_ctas_clientes.TBL_CUENTAS;
DROP TABLE IF EXISTS esq_ctas_clientes.TBL_CLIENTES;


CREATE TABLE esq_ctas_clientes.TBL_CLIENTES(
  codigo VARCHAR(15) NOT NULL,-- dni,pasaporte
  nombres VARCHAR(200) NOT NULL
)TABLESPACE ts_data_ctas_clientes;
ALTER TABLE IF EXISTS esq_ctas_clientes.TBL_CLIENTES ADD CONSTRAINT XPKTBL_CLIENTES PRIMARY KEY(codigo);


CREATE TABLE esq_ctas_clientes.TBL_CUENTAS(
   cuenta VARCHAR(20) NOT NULL,
   cliente VARCHAR(15) NOT NULL, 
   monto NUMERIC NOT NULL DEFAULT 0.0
)TABLESPACE ts_data_ctas_clientes;
ALTER TABLE IF EXISTS esq_ctas_clientes.TBL_CUENTAS ADD CONSTRAINT XPKTBL_CUENTAS PRIMARY KEY(cuenta);
ALTER TABLE IF EXISTS esq_ctas_clientes.TBL_CUENTAS ADD CONSTRAINT R1 FOREIGN KEY(cliente) REFERENCES esq_ctas_clientes.TBL_CLIENTES(codigo);


CREATE TABLE esq_ctas_clientes.TBL_MOVIMIENTOS(
   codigo INTEGER NOT NULL,
   cuenta VARCHAR(20) NOT NULL,
   monto NUMERIC NOT NULL DEFAULT 0.0,
   transaccion VARCHAR(5)NOT NULL,
   fechamov TIMESTAMP NOT NULL,
   causalmov VARCHAR(120) NOT NULL,
   acreedor VARCHAR(15)
	
) TABLESPACE ts_data_ctas_clientes;
ALTER TABLE IF EXISTS esq_ctas_clientes.TBL_MOVIMIENTOS ADD CONSTRAINT XPKTBL_MOVIMIENTOS PRIMARY KEY(codigo);
ALTER TABLE IF EXISTS esq_ctas_clientes.TBL_MOVIMIENTOS ALTER COLUMN codigo SET DEFAULT nextval('esq_ctas_clientes."SEQ_TBL_MOVIMIENTOS"');
ALTER TABLE IF EXISTS esq_ctas_clientes.TBL_MOVIMIENTOS ADD CONSTRAINT R2 FOREIGN KEY(cuenta) REFERENCES esq_ctas_clientes.TBL_CUENTAS(cuenta);


--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION esq_ctas_clientes.fn_cargo_cuenta(
  in_cuenta VARCHAR(20),
  in_monto NUMERIC, 
  in_cliente  VARCHAR(15),
  in_causalmov VARCHAR(120),
  in_acreedor VARCHAR(15),
  in_transaccion VARCHAR(5)
  ) RETURNS VARCHAR(120) AS $$
 DECLARE resultado VARCHAR(20);
 DECLARE v_transaccion VARCHAR(20);
 DECLARE v_monto NUMERIC;
 
 BEGIN
    resultado:='0000';
    v_transaccion:=in_transaccion ;
	if not exists (select cuenta from esq_ctas_clientes.TBL_CUENTAS where cuenta=in_cuenta)
	 then
	  RAISE EXCEPTION 'Nonexistent Cuenta --> %', in_cuenta;
	end if;
	if not exists (select cuenta from esq_ctas_clientes.TBL_CUENTAS where cliente=in_cliente)
	 then
	  RAISE EXCEPTION 'No existe cliente --> %', in_cliente;
	end if;
	
	
      select monto into v_monto from esq_ctas_clientes.TBL_CUENTAS where cuenta=in_cuenta;
      v_monto:=v_monto-in_monto;
	  if v_monto>0
	  then
	      UPDATE esq_ctas_clientes.TBL_CUENTAS SET monto = v_monto where cuenta=in_cuenta;
		  INSERT  INTO esq_ctas_clientes.TBL_MOVIMIENTOS(cuenta,monto,transaccion,fechamov,causalmov,acreedor) VALUES(in_cuenta,in_monto,v_transaccion,current_timestamp,in_causalmov,in_acreedor); 
		  return resultado|| '- Proceso Conforme '||'- codtransaccion='||v_transaccion;
	  else
	       RAISE EXCEPTION 'Saldo insuficiente para pagar deuda --> %', in_monto;
	  end if;  

	EXCEPTION WHEN others then
    return SQLSTATE || '-' || SQLERRM;
 END;
 $$ LANGUAGE plpgsql;
 
 CREATE OR REPLACE FUNCTION esq_ctas_clientes.fn_reversa_cargo_cuenta(
  in_transaccion VARCHAR(5)
  ) RETURNS VARCHAR(120) AS $$
 DECLARE resultado VARCHAR(5);
 DECLARE v_monto NUMERIC;
 DECLARE v_cuenta VARCHAR(20);
 BEGIN
    resultado:='0000';
	if not exists (select cuenta from esq_ctas_clientes.TBL_MOVIMIENTOS where transaccion=in_transaccion)
	 then
	  RAISE EXCEPTION 'No existent id Transaccion --> %', in_transaccion;
	end if;
    select cuenta,monto into v_cuenta, v_monto from esq_ctas_clientes.TBL_MOVIMIENTOS where transaccion=in_transaccion;
	UPDATE esq_ctas_clientes.TBL_CUENTAS SET monto = (monto+v_monto) where cuenta=v_cuenta;
	INSERT  INTO esq_ctas_clientes.TBL_MOVIMIENTOS(cuenta,monto,transaccion,fechamov,causalmov,acreedor,idtrxrversa) (select cuenta,monto,nextval('SEQ_PAGO_ID') as transaccion, current_timestamp as fechamov, 'reversion' as causalmov,acreedor,transaccion as idtrxrversa from esq_ctas_clientes.TBL_MOVIMIENTOS cr WHERE cr.transaccion=in_transaccion); 
	
	return resultado || '- Proceso Conforme '; 
  	
	EXCEPTION WHEN others then
    return SQLSTATE || '-' || SQLERRM;
 END

 
 $$ LANGUAGE plpgsql;





------------------------------------------------------------------------------------

delete from esq_ctas_clientes.TBL_CUENTAS;
delete from esq_ctas_clientes.TBL_CLIENTES;
delete from esq_ctas_clientes.TBL_MOVIMIENTOS;
--select * from esq_ctas_clientes.TBL_CLIENTES;
select * from esq_ctas_clientes.TBL_CUENTAS;
insert INTO esq_ctas_clientes.TBL_CLIENTES(codigo,nombres) VALUES('15865658','Jose Diaz Sarmiento');
insert INTO esq_ctas_clientes.TBL_CUENTAS(cuenta,cliente,monto) VALUES ('11205060709500','15865658',500.40);	


--select  esq_ctas_clientes.fn_cargo_cuenta('11205060709500',10,'15865658','PGTR-PAGO TELEFONIA','20602649412' )
--select * from esq_ctas_clientes.TBL_MOVIMIENTOS;

------------------------------------------------------------------------------------
ALTER TABLE esq_ctas_clientes.TBL_MOVIMIENTOS ADD COLUMN idtrxrversa VARCHAR(5) NULL;
